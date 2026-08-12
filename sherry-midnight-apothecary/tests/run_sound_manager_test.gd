extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("SOUND MANAGER TEST FAILED: %s" % message)


func _run() -> void:
	var sound_manager := root.get_node_or_null("SoundManager")
	_expect(sound_manager != null, "SoundManager autoload is available.")
	if sound_manager == null:
		quit(1)
		return
	sound_manager.play_day_interior_bgm()
	var bgm := sound_manager.get_node_or_null("PersistentBGM") as AudioStreamPlayer
	_expect(bgm != null and bgm.playing, "The shared daytime interior BGM starts from SoundManager.")
	var master_bus := AudioServer.get_bus_index("Master")
	var master_volume_before := AudioServer.get_bus_volume_db(master_bus)
	var bgm_bus := AudioServer.get_bus_index("DayInteriorBGM")
	_expect(bgm_bus >= 0 and bgm != null and bgm.bus == &"DayInteriorBGM", "The persistent BGM uses its dedicated effects bus.")
	_expect(AudioServer.get_bus_effect_count(bgm_bus) == 3, "The BGM bus owns reverb, stereo enhancement and low-pass effects.")
	var looping_bgm := bgm.stream as AudioStreamWAV if bgm != null else null
	_expect(looping_bgm != null and looping_bgm.loop_mode == AudioStreamWAV.LOOP_FORWARD, "The shared daytime interior BGM loops forward without a fade transition.")
	sound_manager.set_day_interior_menu_profile()
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(bgm_bus), -10.0), "The menu profile places the music at -10 dB.")
	var menu_reverb := AudioServer.get_bus_effect(bgm_bus, 0) as AudioEffectReverb
	var menu_room_size := menu_reverb.room_size
	sound_manager.set_day_interior_transition(0.63)
	_expect(AudioServer.get_bus_volume_db(bgm_bus) > -10.0 and AudioServer.get_bus_volume_db(bgm_bus) < -2.0, "The forest transition profile is between the menu and room gain.")
	sound_manager.set_day_interior_room_profile()
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(bgm_bus), -2.0), "The room profile places the music at -2 dB.")
	_expect(menu_reverb.room_size < menu_room_size, "The room profile shortens the menu reverb space.")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(master_bus), master_volume_before), "BGM profiling does not alter the Master bus volume.")
	if bgm != null:
		bgm.seek(2.0)
		sound_manager.play_day_interior_bgm()
		_expect(bgm.get_playback_position() > 1.0, "Requesting the same BGM preserves its playback position.")

	var button := Button.new()
	button.text = "Sound test"
	root.add_child(button)
	await process_frame
	_expect(button.has_meta(&"sound_manager_bound"), "Runtime-created buttons receive SFX bindings.")
	_expect(button.pressed.get_connections().size() > 0, "Button press feedback is connected.")
	_expect(button.mouse_entered.get_connections().size() > 0, "Button hover feedback is connected.")

	var initial_players := sound_manager.get_child_count()
	sound_manager.play_footstep(0.5)
	sound_manager.play_spell_cast()
	sound_manager.play_spell_release()
	sound_manager.play_door_transition()
	sound_manager.play_ui_hover()
	sound_manager.play_ui_press()
	_expect(sound_manager.get_child_count() >= initial_players + 6, "Every public SFX path starts one-shot playback.")

	button.queue_free()
	for child in sound_manager.get_children():
		if child is AudioStreamPlayer:
			child.queue_free()
	await process_frame
	await process_frame
	if failures == 0:
		print("Sound manager loading, playback and automatic UI binding tests passed.")
		quit(0)
	else:
		push_error("%d sound manager assertion(s) failed." % failures)
		quit(1)
