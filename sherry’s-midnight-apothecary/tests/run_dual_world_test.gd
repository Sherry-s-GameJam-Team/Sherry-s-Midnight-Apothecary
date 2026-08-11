extends Node

var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("DUAL WORLD TEST FAILED: %s" % message)


func _run() -> void:
	var level := preload("res://day/levels/_tests/dual_world/dual_world_puzzle_demo.tscn").instantiate()
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

	_expect(manager.current_world == DualWorldManager.WorldState.CORRUPTED, "Sherry starts in CORRUPTED.")
	_expect(level.get_node("CorruptedWorld").visible and not level.get_node("OriginalWorld").visible, "Only the corrupted visual starts visible.")
	_expect(sherry.is_physics_processing() and not luca.input_enabled and not luca.is_physics_processing(), "Only Sherry starts under player control and physics.")
	_expect(not level.get_node("CorruptedWorld/Collision/CorruptionWall/CollisionShape2D").disabled, "Current-world collision starts enabled.")
	_expect(level.get_node("OriginalWorld/Collision/OriginalBridge/CollisionShape2D").disabled, "Hidden-world collision starts disabled.")
	var sherry_start := sherry.global_position
	var luca_start := luca.global_position

	_expect(await controller.request_switch(), "A safe switch to Luca succeeds.")
	await get_tree().physics_frame
	_expect(manager.current_world == DualWorldManager.WorldState.ORIGINAL, "Luca selects ORIGINAL.")
	_expect(level.get_node("CorruptedWorld/Collision/CorruptedStep/CollisionShape2D").disabled, "Corrupted-exclusive collision turns off with its visuals.")
	_expect(not level.get_node("OriginalWorld/Collision/OriginalBridge/CollisionShape2D").disabled, "Original-exclusive collision turns on with its visuals.")
	_expect(controller.camera.get_parent() == luca, "The existing Camera2D follows Luca.")
	_expect(is_equal_approx(sherry.global_position.x, sherry_start.x) and is_equal_approx(luca.global_position.x, luca_start.x), "Switching preserves both independent actor X positions.")
	_expect(not sherry.global_position.is_equal_approx(luca.global_position), "Switching never snaps the inactive actor onto the active actor.")
	_expect(luca.input_enabled and not sherry.is_physics_processing(), "Only Luca receives movement after switching.")

	level._on_anchor_body_entered(luca)
	await get_tree().physics_frame
	_expect(state.is_flag_set(&"luca_anchor_01"), "Luca changes level-local shared puzzle state.")
	_expect(level.get_node("CorruptedWorld/Visual/StabilizedBridgeVisual").visible, "Luca reveals Sherry's stabilized route.")
	_expect(not level.get_node("CorruptedWorld/Visual/CorruptionWallVisual").visible, "Luca removes Sherry's corruption wall.")

	_expect(await controller.request_switch(), "A safe switch back to Sherry succeeds.")
	await get_tree().physics_frame
	_expect(manager.current_world == DualWorldManager.WorldState.CORRUPTED, "Sherry reselects CORRUPTED.")
	_expect(controller.camera.get_parent() == sherry, "The existing Camera2D returns to Sherry.")
	level._on_seal_body_entered(sherry)
	await get_tree().physics_frame
	_expect(state.is_flag_set(&"sherry_seal_01"), "Sherry changes the shared seal state.")
	_expect(level.get_node("SharedWorld/SharedCollision/FinalGate/CollisionShape2D").disabled, "The shared final gate collision opens.")

	luca.global_position = Vector2(1150, 650)
	controller.debug_switch_warnings = false
	var blocked := not await controller.request_switch()
	_expect(blocked, "Switching is blocked when Luca's saved position overlaps ORIGINAL terrain.")
	_expect(manager.current_world == DualWorldManager.WorldState.CORRUPTED, "A blocked switch keeps the active world unchanged.")

	level.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("Dual-world protagonist, collision, shared-state and safety tests passed.")
		get_tree().quit(0)
	else:
		push_error("%d dual-world assertion(s) failed." % failures)
		get_tree().quit(1)
