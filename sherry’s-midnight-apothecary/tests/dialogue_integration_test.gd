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
	var test_scene_resource := load(TEST_SCENE_PATH) as PackedScene
	test.expect(test_scene_resource != null, "Dialogue test scene loads.")
	if test_scene_resource != null:
		var test_scene := test_scene_resource.instantiate()
		test_scene.auto_start = false
		var tree := Engine.get_main_loop() as SceneTree
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
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(balloon)
	test.expect(balloon.get_node("%DialogueLabel") is DialogueLabel, "Balloon contains DialogueLabel.")
	test.expect(balloon.get_node("%ResponsesMenu") is DialogueResponsesMenu, "Balloon contains DialogueResponsesMenu.")

	for button_name: String in ["FastButton", "AutoButton", "BackButton", "SettingsButton", "LoadButton"]:
		var button := balloon.get_node("%" + button_name) as TextureButton
		test.expect(button != null, "%s is a TextureButton." % button_name)
		test.expect(button.texture_normal != null, "%s has normal art." % button_name)
		test.expect(button.texture_hover != null, "%s has hover art." % button_name)
		test.expect(button.texture_pressed != null, "%s has pressed art." % button_name)
	balloon.free()
