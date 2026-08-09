extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("LUCA PLAYER TEST FAILED: %s" % message)


func _run() -> void:
	var luca := preload("res://art/characters/luca/luca_player.tscn").instantiate() as LucaPlayer
	luca.input_enabled = false
	root.add_child(luca)
	await process_frame

	var frames := luca.animated_sprite.sprite_frames
	_expect(frames.get_frame_count(&"idle") == 29, "Idle uses frames 001-029.")
	_expect(frames.get_animation_loop(&"idle"), "Idle loops.")
	_expect(frames.get_frame_count(&"run_start") == 20, "Run start uses frames 064-083.")
	_expect(not frames.get_animation_loop(&"run_start"), "Run start is one-shot.")
	_expect(frames.get_frame_count(&"run_loop") == 13, "Run loop uses frames 084-096.")
	_expect(frames.get_animation_loop(&"run_loop"), "Run loop loops.")

	luca.set_movement_direction(1.0)
	await physics_frame
	await physics_frame
	_expect(luca.get_locomotion_state_name() == &"run_start", "A new movement begins with run_start.")
	_expect(luca.velocity.x > 0.0, "Right input moves Luca right.")
	_expect(luca.animated_sprite.flip_h, "Right movement flips the left-facing source art.")

	luca._on_animation_finished()
	_expect(luca.get_locomotion_state_name() == &"run_loop", "Held movement enters run_loop after run_start.")
	luca.stop_moving()
	_expect(luca.get_locomotion_state_name() == &"idle", "Stopping returns Luca to idle.")

	luca.set_movement_direction(-1.0)
	await physics_frame
	await physics_frame
	_expect(luca.get_locomotion_state_name() == &"run_start", "The next movement replays run_start exactly once.")
	_expect(not luca.animated_sprite.flip_h, "Left movement keeps the source orientation.")

	luca.queue_free()
	await process_frame
	if failures == 0:
		print("Luca player animation and movement tests passed.")
		quit(0)
	else:
		push_error("%d Luca player assertion(s) failed." % failures)
		quit(1)
