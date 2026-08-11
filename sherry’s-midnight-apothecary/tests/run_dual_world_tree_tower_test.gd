extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("TREE TOWER TEST FAILED: %s" % message)


func _run() -> void:
	var level := preload("res://day/levels/_tests/dual_world_tree_tower/tree_tower_demo.tscn").instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame
	var manager: DualWorldManager = level.get_node("Systems/DualWorldManager")
	var controller: DualProtagonistController = level.get_node("Systems/DualProtagonistController")
	var state: DualWorldState = level.get_node("Systems/DualWorldState")
	var sherry: CharacterBody2D = level.get_node("Actors/Sherry")
	var luca: CharacterBody2D = level.get_node("Actors/Luca")
	manager.fade_out_duration = 0.0
	manager.fade_in_duration = 0.0

	_expect(manager.current_world == DualWorldManager.WorldState.CORRUPTED, "Tower starts with Sherry in CORRUPTED.")
	_expect(not level.get_node("CorruptedWorld/Collision/LucaGate/CollisionShape2D").disabled, "Sherry's corrupted view closes the Luca room gate.")
	var sherry_start := sherry.global_position
	var luca_start := luca.global_position

	_expect(await controller.request_switch(), "Tower safely switches to Luca.")
	await get_tree().physics_frame
	_expect(manager.current_world == DualWorldManager.WorldState.ORIGINAL, "Luca selects the ORIGINAL control room.")
	_expect(level.get_node("CorruptedWorld/Collision/LucaGate/CollisionShape2D").disabled, "The Luca room gate collision is absent in ORIGINAL.")
	_expect(controller.camera.get_parent() == luca, "The tower camera follows Luca.")
	_expect(level.operate_console(&"A"), "Luca operates remote platform A.")
	_expect(state.is_flag_set(&"tree_platform_a_right"), "Platform A state is shared independently from world visuals.")

	_expect(await controller.request_switch(), "Tower switches back to Sherry.")
	await get_tree().physics_frame
	_expect(level.activate_potion(&"GROWTH"), "Sherry activates Growth.")
	await get_tree().physics_frame
	_expect(level.get_node("CorruptedWorld/WorldObjects/RootStep1").visible, "Growth reveals root steps.")
	_expect(not level.get_node("CorruptedWorld/WorldObjects/RootStep1/Body/CollisionShape2D").disabled, "Growth root collision is active in CORRUPTED.")

	_expect(await controller.request_switch(), "Tower returns to Luca for lift controls.")
	await get_tree().physics_frame
	_expect(level.operate_console(&"B") and level.operate_console(&"C"), "Luca changes remote platforms B and C.")
	_expect(state.is_flag_set(&"tree_platform_b_high") and state.is_flag_set(&"tree_platform_c_left"), "B and C states persist across actor switches.")

	_expect(await controller.request_switch(), "Tower returns to Sherry for potion route changes.")
	await get_tree().physics_frame
	_expect(level.activate_potion(&"FREEZE"), "Sherry activates Freeze.")
	_expect(level.activate_potion(&"BLAST"), "Sherry activates Blast.")
	await get_tree().physics_frame
	_expect(level.get_node("CorruptedWorld/WorldObjects/SapStep1").visible, "Freeze reveals sap steps.")
	_expect(not level.get_node("CorruptedWorld/WorldObjects/SapStep1/Body/CollisionShape2D").disabled, "Frozen sap collision is active for Sherry.")
	_expect(not level.get_node("CorruptedWorld/WorldObjects/RottenBarrier").visible, "Blast removes rotten bark visuals.")
	_expect(level.get_node("CorruptedWorld/WorldObjects/RottenBarrier/Body/CollisionShape2D").disabled, "Blast removes rotten bark collision.")
	level._on_goal_body_entered(sherry)
	_expect(state.is_flag_set(&"tree_goal_reached"), "Sherry can complete the tree-crown goal after Blast.")
	_expect(is_equal_approx(sherry_start.x, 760.0) and is_equal_approx(luca_start.x, 680.0), "The tower keeps independent actor start positions.")

	level.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("Dual-world Giant Tree Tower tests passed.")
		get_tree().quit(0)
	else:
		push_error("%d Giant Tree Tower assertion(s) failed." % failures)
		get_tree().quit(1)

