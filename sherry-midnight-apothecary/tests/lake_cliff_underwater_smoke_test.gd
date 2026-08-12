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
	_assert(scene.camera.enabled and not scene.camera.position_smoothing_enabled, "single-stage camera controller is active")
	_assert(is_equal_approx(scene.camera_player_offset.y, -410.0), "player camera is shifted upward by 500 units")
	_assert(is_equal_approx(scene.camera_elevator_offset.y, -540.0), "elevator camera is shifted upward by 500 units")
	var water_surface := scene.get_node("World/WaterSurface")
	var water_planes := 0
	for water_layer in water_surface.get_children():
		if water_layer is LakeWaterSurface:
			water_planes += 1
			_assert((water_layer as CanvasItem).material == null, "%s has no surface shader" % water_layer.name)
	_assert(water_planes == 2, "water surface uses exactly two texture planes")
	var water_bottom := scene.get_node("World/WaterSurface/WaterBottom") as LakeWaterSurface
	var surface := scene.get_node("World/WaterSurface/Surface") as LakeWaterSurface
	_assert(water_bottom.texture != null and surface.texture != null, "surface and bottom textures are assigned")
	_assert(absf(water_bottom.position.y - scene.water_y) <= water_bottom.bob_amplitude + 0.5, "bottom texture begins at physical water_y")
	_assert(absf(surface.position.y + surface.texture.get_height() - scene.water_y) <= surface.bob_amplitude + 0.5, "surface texture ends at physical water_y")
	var water_origin := water_bottom.position
	scene.camera.global_position = Vector2(1086.0, scene.elevator_bottom_y)
	await process_frame
	await process_frame
	_assert(absf(water_bottom.position.y - water_origin.y) <= water_bottom.bob_amplitude + 0.5, "water remains at surface when camera reaches lakebed")
	_assert(scene.elevator != null, "elevator resolves")
	_assert(scene.get_node_or_null("EntryPoints/default") != null, "day runtime entry point exists")
	var nested_player := scene.get_node("World/UnderwaterArea/GameplayRuins/LakebedVisual/Player") as CharacterBody2D
	var nested_camera := scene.get_node("World/UnderwaterArea/GameplayRuins/LakebedVisual/Player/Camera2D") as Camera2D
	var lakebed_visual := scene.get_node("World/UnderwaterArea/GameplayRuins/LakebedVisual") as Node2D
	var lakebed_backdrop := scene.get_node("World/UnderwaterArea/GameplayRuins/LakebedBackdrop") as Sprite2D
	var lakebed_background := lakebed_visual.get_node("Background") as Parallax2D
	var lakebed_ground := lakebed_visual.get_node("Ground") as Parallax2D
	_assert(lakebed_visual.visible, "lakebed visual root is visible")
	_assert(lakebed_backdrop.visible and lakebed_backdrop.texture != null, "lakebed backdrop is a visible world-space sprite")
	_assert(lakebed_backdrop.z_index > -42 and lakebed_backdrop.z_index < 0, "lakebed backdrop is above water mask and behind gameplay")
	_assert(not lakebed_background.visible, "nested parallax background cannot interfere with canvas ordering")
	_assert(lakebed_ground.visible, "lakebed ground remains visible")
	_assert(is_equal_approx(lakebed_visual.global_position.y, 3670.0), "lakebed visual is positioned in underwater background layer")
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
