extends Node

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
		"EntryPoints/default", "Player", "Luca", "Exterior", "Interior", "Crown",
		"WorldBounds", "BossInterface"
	]:
		_check(forest.get_node_or_null(path) != null, "Missing required node: %s" % path)

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

	var spray = forest.get_node("Interior/LucaWorldOnly/SprayDevice")
	spray.pressure = 0.0
	_check(not spray.can_spray(), "Spray fired with insufficient pressure")
	spray.pressure = spray.max_pressure
	_check(spray.can_spray(), "Spray unavailable at full pressure")

	var luca_world = forest.get_node("ForestController/LucaWorldController")
	luca_world.set_luca_view(true)
	_check(forest.get_node("Interior/LucaWorldOnly").visible, "Luca old-world layer did not show")
	luca_world.set_luca_view(false)
	_check(not forest.get_node("Interior/LucaWorldOnly").visible, "Luca old-world layer did not hide")

	var lift = forest.get_node("Interior/RootLift")
	lift.set_raised(true)
	await get_tree().create_timer(0.9).timeout
	_check(lift.raised, "Root lift failed")

	var rotating = forest.get_node("Interior/RotatingRoot")
	rotating.rotate_to_next()
	await get_tree().create_timer(0.65).timeout
	_check(rotating.current_slot == 1, "Rotating root failed")

	var sluice = forest.get_node("Interior/SluiceGate")
	sluice.set_opened(true)
	await get_tree().create_timer(0.1).timeout
	_check(sluice.opened, "Sluice gate failed")

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
