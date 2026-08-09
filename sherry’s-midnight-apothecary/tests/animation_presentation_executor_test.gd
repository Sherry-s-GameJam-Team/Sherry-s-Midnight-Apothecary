extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://day/systems/animation_presentation/animation_presentation_executor.tscn") as PackedScene
	test.expect(scene != null, "Animation presentation executor scene loads.")
	if scene == null:
		return
	var root := Node2D.new()
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(20, 30)
	var camera := Camera2D.new()
	player.add_child(camera)
	var player_visual := Node2D.new()
	player_visual.name = "PlayerVisual"
	player.add_child(player_visual)
	var spawn_point := Marker2D.new()
	spawn_point.name = "SpawnPoint"
	spawn_point.position = Vector2(240, 360)
	var animation := AnimatedSprite2D.new()
	animation.name = "Animation"
	animation.sprite_frames = _make_frames(false)
	animation.animation = &"sequence"
	var executor := scene.instantiate() as AnimationPresentationExecutor
	executor.auto_start = false
	executor.animation_path = NodePath("../Animation")
	executor.player_path = NodePath("../Player")
	executor.player_visual_path = NodePath("../Player/PlayerVisual")
	executor.spawn_point_path = NodePath("../SpawnPoint")
	root.add_child(player)
	root.add_child(spawn_point)
	root.add_child(animation)
	root.add_child(executor)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(root)
	player.set_physics_process(true)

	var completed_count := [0]
	executor.completed.connect(func() -> void: completed_count[0] += 1)
	executor.start()
	test.expect(player.visible, "Player root stays visible so its child camera remains active.")
	test.expect(not player_visual.visible, "Only the player artwork is hidden while the presentation runs.")
	test.expect_equal(player.process_mode, Node.PROCESS_MODE_INHERIT, "Presentation locking does not disable the player's child camera.")
	test.expect(not player.is_physics_processing(), "Player physics is disabled while the animation runs.")
	test.expect(camera.can_process(), "A Camera2D child keeps processing during the presentation.")
	animation.animation_finished.emit()
	test.expect_equal(player.global_position, spawn_point.global_position, "Player is moved to the configured spawn marker after the animation.")
	test.expect(player.visible, "Player is revealed after the presentation animation.")
	test.expect(player_visual.visible, "Player artwork is revealed after the presentation animation.")
	test.expect_equal(player.process_mode, Node.PROCESS_MODE_INHERIT, "Player processing is restored after the animation.")
	test.expect(player.is_physics_processing(), "Player physics is restored after the animation.")
	test.expect(animation.is_queued_for_deletion(), "Completed animation node is queued for removal.")
	test.expect_equal(completed_count[0], 1, "Completion is emitted once.")
	animation.animation_finished.emit()
	test.expect_equal(completed_count[0], 1, "Duplicate completion signals are ignored.")
	root.free()

	var loop_root := Node2D.new()
	var loop_player := CharacterBody2D.new()
	loop_player.name = "Player"
	var loop_spawn := Marker2D.new()
	loop_spawn.name = "SpawnPoint"
	var loop_animation := AnimatedSprite2D.new()
	loop_animation.name = "Animation"
	loop_animation.sprite_frames = _make_frames(true)
	loop_animation.animation = &"sequence"
	var loop_executor := scene.instantiate() as AnimationPresentationExecutor
	loop_executor.auto_start = false
	loop_executor.animation_path = NodePath("../Animation")
	loop_executor.player_path = NodePath("../Player")
	loop_executor.spawn_point_path = NodePath("../SpawnPoint")
	loop_root.add_child(loop_player)
	loop_root.add_child(loop_spawn)
	loop_root.add_child(loop_animation)
	loop_root.add_child(loop_executor)
	tree.root.add_child(loop_root)
	loop_executor.start()
	test.expect(loop_player.visible, "Looping animations are rejected without hiding the player.")
	test.expect(not loop_animation.is_playing(), "Looping animations are not started by the executor.")
	loop_root.free()


static func _make_frames(loop: bool) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(&"sequence")
	frames.set_animation_loop(&"sequence", loop)
	return frames
