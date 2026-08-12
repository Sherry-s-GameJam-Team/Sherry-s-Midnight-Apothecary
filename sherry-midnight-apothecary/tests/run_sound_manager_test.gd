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
