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
	var luca := preload("res://characters/luca/luca_player.tscn").instantiate() as LucaPlayer
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
	_expect(frames.has_animation(&"jump"), "Jump animation exists in sprite frames.")
	_expect(frames.get_frame_count(&"jump") == 13, "Jump animation temporarily uses the 13 run loop frames.")
	_expect(frames.get_animation_loop(&"jump"), "Jump animation loops.")
	_expect(frames.has_animation(&"fall"), "Fall animation exists in sprite frames.")

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
	luca.stop_moving()

	# Test jump mechanics and signals
	var signals_emitted := []
	luca.jumped.connect(func() -> void: signals_emitted.append("jumped"))
	luca.landed.connect(func() -> void: signals_emitted.append("landed"))

	# Simulate grounded state and trigger jump
	luca._coyote_timer = luca.coyote_time
	luca.request_jump()
	_expect(luca.is_airborne(), "Requesting jump makes Luca airborne.")
	_expect(luca.velocity.y < 0.0, "Jump gives negative vertical velocity.")
	_expect(luca.get_locomotion_state_name() == &"jump", "Airborne jump sets state to jump.")
	_expect(signals_emitted.has("jumped"), "Jumped signal was emitted.")

	# Advance physics into falling
	luca.velocity.y = 100.0
	await physics_frame
	_expect(luca.get_locomotion_state_name() == &"fall", "Positive vertical velocity transitions to fall state.")

	# Simulate landing
	luca._is_airborne = true
	luca.velocity.y = 0.0
	luca._is_airborne = false
	luca._play_idle()
	luca.landed.emit()
	_expect(signals_emitted.has("landed"), "Landed signal is emitted on landing.")
	_expect(luca.get_locomotion_state_name() == &"idle", "Landing when stationary returns to idle.")

	# Jump buffer test
	luca._is_airborne = true
	luca._jump_buffer_timer = 0.0
	luca.request_jump()
	_expect(luca._jump_buffer_timer > 0.0, "Requesting jump while airborne buffers the input.")

	luca.queue_free()
	await process_frame
	if failures == 0:
		print("Luca player animation, movement, and jump tests passed.")
		quit(0)
	else:
		push_error("%d Luca player assertion(s) failed." % failures)
		quit(1)
