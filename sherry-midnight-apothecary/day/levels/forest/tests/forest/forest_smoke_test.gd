extends Node

## Exterior forest smoke test.
## The interior is a standalone level now (res://day/levels/forest/interior/,
## registered in DayRuntime.LEVELS). This test covers the exterior scene and
## the tree-gate handoff to the interior level; the interior itself is covered
## by res://tests/forest_interior_smoke_test.gd.

const FOREST_SCENE := preload("res://day/levels/forest/forest.tscn")
const LOTUS_SCENE := preload("res://day/levels/forest/exterior/lotus_platform.tscn")
const WHEEL_SCENE := preload("res://day/levels/forest/exterior/waterwheel.tscn")
const MUD_SCENE := preload("res://day/levels/forest/exterior/corrupted_mud.tscn")

var failures: Array[String] = []

func _ready() -> void:
	await _run()
	if failures.is_empty():
		print("FOREST_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for message in failures:
			push_error(message)
		print("FOREST_SMOKE_TEST: FAIL (%d)" % failures.size())
		get_tree().quit(1)

func _run() -> void:
	var forest := FOREST_SCENE.instantiate()
	add_child(forest)
	await get_tree().process_frame
	for path in [
		"EntryPoints/default", "Player", "Luca", "Exterior", "Crown",
		"WorldBounds", "BossInterface", "ForestController/LucaWorldController",
		"ForestController/PartyController", "Exterior/ArvisTreeGate",
		"Exterior/InteriorEntrance", "UI"
	]:
		_check(forest.get_node_or_null(path) != null, "Missing required node: %s" % path)
	_check(forest.get_node_or_null("Interior") == null, "Interior must not be embedded in the exterior scene anymore")

	var switch_events := InputMap.action_get_events(&"switch_character")
	_check(switch_events.any(func(event): return event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_C), "C is not mapped to switch_character")
	var roll_events := InputMap.action_get_events(&"roll")
	_check(roll_events.any(func(event): return event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_Q), "Q is not mapped to roll")

	var lotus := LOTUS_SCENE.instantiate()
	add_child(lotus)
	lotus.receive_potion_hit({"potion_id": &"any_potion"})
	await get_tree().physics_frame
	_check(lotus.activated, "Potion impact did not activate lotus")
	lotus.activate()
	_check(lotus.activated, "Lotus repeated activation changed state")

	var wheel := WHEEL_SCENE.instantiate()
	add_child(wheel)
	wheel.activate_from_water()
	await get_tree().create_timer(1.2).timeout
	_check(wheel.active, "Waterwheel did not activate")

	var mud := MUD_SCENE.instantiate()
	add_child(mud)
	mud.receive_potion_hit({"potion_id": &"purification_potion"})
	await get_tree().create_timer(0.45).timeout
	_check(mud.is_purified, "Purification potion did not purify mud")

	var party = forest.get_node("ForestController/PartyController")
	_check(party != null and party.sherry != null and party.luca != null, "Party controller failed to resolve characters")
	party.enable_switching(true)
	party.set_active_character(&"luca")
	_check(party.active_character == &"luca", "Party controller could not switch to Luca")
	party.set_active_character(&"sherry")
	_check(party.active_character == &"sherry", "Party controller could not switch back to Sherry")

	# Tree-gate handoff: with no DayRuntime in the tree, enter_interior must
	# safely no-op instead of erroring or moving the player.
	forest.tree_gate_opened = true
	var before: Vector2 = forest.player.global_position
	forest.enter_interior(forest.player)
	await get_tree().physics_frame
	_check(forest.player.global_position == before, "enter_interior should not move the player without a DayRuntime")

	var boss = forest.get_node("BossInterface")
	boss.begin_boss()
	_check(boss.started, "Boss begin interface failed")
	boss.purify_boss()
	await get_tree().process_frame
	_check(boss.purified, "Boss purification interface failed")
	_check(not forest.is_corrupted(), "Forest did not switch to normal after boss purification")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
