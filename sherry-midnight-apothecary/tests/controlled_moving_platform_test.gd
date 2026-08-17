extends RefCounted

const PLATFORM_SCENE := preload("res://day/interactables/control_system/controlled_moving_platform.tscn")


static func run(test: TestSupport) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var platform := PLATFORM_SCENE.instantiate() as ControlledMovingPlatform
	var marker := platform.get_node_or_null("DestinationMarker") as Marker2D
	if marker != null:
		marker.position = Vector2(100.0, 0.0)
	platform.travel_time = 1.0
	platform.pause_time = 0.0
	tree.root.add_child(platform)
	platform.set_physics_process(false)

	var origin := platform.global_position

	test.expect(not platform._moving, "ControlledMovingPlatform starts stationary.")

	platform.set_controlled_active(true)
	test.expect(platform._moving, "ControlledMovingPlatform starts moving when activated.")

	platform._physics_process(0.5)
	test.expect(
		platform.global_position.is_equal_approx(origin + Vector2(50.0, 0.0)),
		"Platform reaches the midpoint after half of travel_time."
	)

	platform._physics_process(0.5)
	test.expect(
		platform.global_position.is_equal_approx(origin + Vector2(100.0, 0.0)),
		"Platform reaches the target offset after travel_time."
	)

	platform._physics_process(0.5)
	test.expect(
		platform.global_position.is_equal_approx(origin + Vector2(50.0, 0.0)),
		"Platform returns to the midpoint after another half travel_time."
	)

	platform.set_controlled_active(false)
	test.expect(not platform._moving, "ControlledMovingPlatform stops when deactivated.")

	var stopped_position := platform.global_position
	platform._physics_process(0.5)
	test.expect(
		platform.global_position.is_equal_approx(stopped_position),
		"Platform holds its position while deactivated."
	)

	platform.free()
