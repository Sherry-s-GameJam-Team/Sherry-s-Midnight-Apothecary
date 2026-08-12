extends SceneTree

const SCENE := preload("res://day/levels/lake/lake_cliff_underwater.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := SCENE.instantiate() as LakeCliffUnderwater
	root.add_child(scene)
	await process_frame
	_assert(scene != null, "main scene instantiates")
	_assert(is_equal_approx(scene.water_y, 1600.0), "water_y is centralized")
	_assert(scene.is_underwater(Vector2(0.0, 1601.0)), "underwater query below surface")
	_assert(not scene.is_underwater(Vector2(0.0, 1599.0)), "underwater query above surface")
	_assert(scene.camera != null and scene.player != null, "camera and player resolve")
	_assert(scene.elevator != null, "elevator resolves")
	_assert(scene.get_node_or_null("EntryPoints/default") != null, "day runtime entry point exists")
	var nested_player := scene.get_node("World/UnderwaterArea/GameplayRuins/LakebedVisual/Player") as CharacterBody2D
	var nested_camera := scene.get_node("World/UnderwaterArea/GameplayRuins/LakebedVisual/Player/Camera2D") as Camera2D
	_assert(not nested_player.visible and nested_player.collision_layer == 0, "nested lakebed player disabled")
	_assert(not nested_camera.enabled, "nested lakebed camera disabled")
	scene.elevator.travel_duration = 0.05
	scene.elevator.start_descent()
	await create_timer(0.35).timeout
	_assert(scene.elevator.state == LakeElevator.State.IDLE_BOTTOM, "elevator reaches bottom")
	_assert(is_equal_approx(scene.elevator.global_position.y, scene.elevator_bottom_y), "bottom stop matches exported coordinate")
	scene.elevator.start_ascent()
	await create_timer(0.35).timeout
	_assert(scene.elevator.state == LakeElevator.State.IDLE_TOP, "elevator returns to top")
	print("LAKE_SCENE_SMOKE_TEST_OK")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Lake scene smoke test failed: %s" % message)
	quit(1)
