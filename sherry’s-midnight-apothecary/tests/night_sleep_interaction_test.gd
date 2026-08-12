extends RefCounted


static func run(test: TestSupport) -> void:
	var packed := load("res://night/levels/home/bedroom.tscn") as PackedScene
	test.expect(packed != null, "Night bedroom scene with sleep interaction loads.")
	if packed == null:
		return
	var bedroom := packed.instantiate() as NightBedroom
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(bedroom)
	var interaction := bedroom.get_node_or_null("SleepInteraction") as NightSleepInteraction
	var animation := bedroom.get_node_or_null("Sleep") as AnimatedSprite2D
	var bed := bedroom.get_node_or_null("Bed") as Sprite2D
	var player := bedroom.get_node_or_null("Player") as CharacterBody2D
	test.expect(interaction != null, "Night bedroom has a typed Sleep interaction node.")
	test.expect(animation != null and animation.sprite_frames != null, "Sleep interaction has its transparent animation.")
	if interaction == null or animation == null or player == null or bed == null:
		bedroom.free()
		return
	test.expect(not animation.sprite_frames.get_animation_loop(&"sleep"), "Sleep animation is non-looping.")
	test.expect_equal(animation.sprite_frames.get_frame_count(&"sleep"), 63, "Sleep animation keeps all 63 source frames.")
	interaction.call("_on_body_entered", player)
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	interaction.call("_input", event)
	test.expect(interaction.is_sleeping(), "Pressing interact in range starts sleeping.")
	test.expect(animation.visible and animation.is_playing(), "The sleep animation becomes visible and plays.")
	test.expect(not bed.visible, "The static bed is hidden during the full sleep animation.")
	test.expect(not player.is_physics_processing(), "Player movement is locked during sleep.")
	var requested := [0]
	bedroom.sleep_requested.connect(func() -> void: requested[0] += 1)
	animation.animation_finished.emit()
	test.expect_equal(requested[0], 1, "Finishing sleep requests the next day once.")
	interaction.call("_input", event)
	animation.animation_finished.emit()
	test.expect_equal(requested[0], 1, "Repeated input and animation signals cannot request a second transition.")
	tree.remove_meta("day_modal_input_locked")
	bedroom.free()
