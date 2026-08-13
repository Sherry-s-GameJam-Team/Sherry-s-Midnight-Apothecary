extends RefCounted

const BALLOON_PATH := "res://night/dialogue/apothecary_balloon.tscn"
const TEST_SCENE_PATH := "res://night/dialogue/dialogue_test_scene.tscn"
const DIALOGUE_PATH := "res://night/dialogue/apothecary_test.dialogue"


static func run(test: TestSupport) -> void:
	var plugin_config := ConfigFile.new()
	test.expect_equal(
		plugin_config.load("res://addons/dialogue_manager/plugin.cfg"),
		OK,
		"Dialogue Manager plugin configuration loads."
	)
	test.expect(
		str(plugin_config.get_value("plugin", "version", "")).begins_with("3."),
		"Dialogue Manager major version is 3."
	)
	test.expect_equal(
		ProjectSettings.get_setting("dialogue_manager/runtime/balloon_path"),
		BALLOON_PATH,
		"Dialogue Manager uses the apothecary balloon at runtime."
	)
	test.expect_equal(
		ProjectSettings.get_setting("dialogue_manager/editor/advanced/custom_test_scene_path"),
		TEST_SCENE_PATH,
		"Dialogue Manager editor uses the custom test scene."
	)

	var dialogue := load(DIALOGUE_PATH) as DialogueResource
	test.expect(dialogue != null, "Chinese test dialogue imports as a DialogueResource.")
	var actor_scene := load("res://tests/dual_world/sherry_dual_world_actor.tscn") as PackedScene
	var dialogue_actor := actor_scene.instantiate() as CharacterBody2D
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(dialogue_actor)
	dialogue_actor.velocity = Vector2(180.0, 0.0)
	dialogue_actor._horizontal_velocity = 180.0
	dialogue_actor._is_rolling = true
	dialogue_actor._play("roll")
	dialogue_actor.set_dialogue_locked(true)
	test.expect(dialogue_actor.is_physics_processing(), "Dialogue locks controls without stopping player physics.")
	test.expect_equal(dialogue_actor.velocity, Vector2(180.0, 0.0), "Dialogue locks controls without rewriting active movement state.")
	test.expect(dialogue_actor.animation_player.is_playing(), "Dialogue locks controls without pausing an active roll animation.")
	dialogue_actor.animation_player.animation_finished.emit(dialogue_actor.animation_player.current_animation)
	test.expect(not dialogue_actor._is_rolling, "Roll completion still clears its state while dialogue controls are locked.")
	dialogue_actor.free()
	var stick_script := FileAccess.get_file_as_string("res://day/levels/home/bedroom_stick_interaction.gd")
	var hound_script := FileAccess.get_file_as_string("res://day/levels/grassland/npc/sleeping_hound/sleeping_hound_npc.gd")
	test.expect(not stick_script.contains("_player.set_physics_process"), "Bedroom note dialogue does not freeze the player state machine.")
	test.expect(not hound_script.contains("_player.set_physics_process"), "Sleeping hound dialogue does not freeze the player state machine.")
	var test_scene_resource := load(TEST_SCENE_PATH) as PackedScene
	test.expect(test_scene_resource != null, "Dialogue test scene loads.")
	if test_scene_resource != null:
		var test_scene := test_scene_resource.instantiate()
		test_scene.auto_start = false
		tree.root.add_child(test_scene)
		var test_pause_menu := test_scene.get_node("%PauseMenu") as PauseMenu
		test.expect(test_pause_menu != null, "Dialogue test scene contains the pause menu.")
		test.expect_equal(
			(test_pause_menu.get_parent() as CanvasLayer).layer,
			200,
			"Pause menu renders above the dialogue balloon."
		)
		var cancel_event := InputEventAction.new()
		cancel_event.action = &"ui_cancel"
		cancel_event.pressed = true
		test_scene._input(cancel_event)
		test.expect(test_pause_menu.visible, "Esc opens the pause menu in the dialogue test scene.")
		test.expect(tree.paused, "Opening pause menu pauses dialogue test scene.")
		test_pause_menu.close()
		test.expect(not tree.paused, "Closing pause menu resumes dialogue test scene.")

		var settings_balloon := (load(BALLOON_PATH) as PackedScene).instantiate() as ApothecaryDialogueBalloon
		test_scene.add_child(settings_balloon)
		(settings_balloon.get_node("%SettingsButton") as TextureButton).pressed.emit()
		test.expect(test_pause_menu.visible, "Dialogue settings button opens pause menu.")
		test.expect_equal(
			test_pause_menu.active_page,
			PauseMenu.Page.SETTINGS,
			"Dialogue settings button opens the settings page."
		)
		test.expect(tree.paused, "Dialogue settings button pauses the scene.")
		test_pause_menu.close()
		settings_balloon.free()
		test_scene.free()

	var balloon_scene := load(BALLOON_PATH) as PackedScene
	test.expect(balloon_scene != null, "Apothecary balloon scene loads.")
	if balloon_scene == null:
		return
	var balloon := balloon_scene.instantiate() as ApothecaryDialogueBalloon
	tree.root.add_child(balloon)
	test.expect(balloon.get_node("%DialogueLabel") is DialogueLabel, "Balloon contains DialogueLabel.")
	test.expect(balloon.get_node("%ResponsesMenu") is DialogueResponsesMenu, "Balloon contains DialogueResponsesMenu.")
	var response_menu := balloon.get_node("%ResponsesMenu") as DialogueResponsesMenu
	var unavailable_response := DialogueResponse.new()
	unavailable_response.id = "unavailable"
	unavailable_response.next_id = DMConstants.ID_END
	unavailable_response.is_allowed = false
	unavailable_response.text = "Unavailable"
	response_menu.responses = [unavailable_response]
	test.expect(response_menu.get_menu_items().is_empty(), "An all-disallowed response list has no focus target and does not index item zero.")
	var progress := balloon.get_node("%Progress") as Control
	test.expect(progress != null, "Balloon contains the animated progress indicator.")
	var progress_mark := progress.get_node("AnimatedMark") as DialogueProgressIndicator
	test.expect(progress_mark.texture != null, "Progress indicator has a transparent sprite sheet.")
	test.expect_equal(progress_mark.hframes * progress_mark.vframes, 100, "Progress sprite sheet exposes all frame cells.")
	test.expect_equal(progress_mark.frame_count, 97, "Progress animation uses the processed MP4 frames.")
	test.expect_equal(progress_mark.frames_per_second, 12.0, "Progress animation uses the MP4 playback rate.")
	progress_mark.frame = 24
	progress_mark.set_playing(false)
	test.expect_equal(progress_mark.frame, 0, "Paused progress indicator displays its first frame.")
	test.expect(not progress_mark.is_playing(), "Progress indicator can hold its first frame.")
	test.expect(balloon.get_node("%FrameDock") is AspectRatioContainer, "Balloon has an animated frame dock.")
	test.expect(balloon.enter_duration > 0.0, "Balloon entrance transition has a duration.")
	test.expect(balloon.exit_duration > 0.0, "Balloon exit transition has a duration.")

	for button_name: String in ["FastButton", "AutoButton", "BackButton", "SettingsButton", "LoadButton"]:
		var button := balloon.get_node("%" + button_name) as TextureButton
		test.expect(button != null, "%s is a TextureButton." % button_name)
		test.expect(button.texture_normal != null, "%s has normal art." % button_name)
		test.expect(button.texture_hover != null, "%s has hover art." % button_name)
		test.expect(button.texture_pressed != null, "%s has pressed art." % button_name)
	balloon.free()
