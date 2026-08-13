extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://night/ui/pause_menu/pause_menu.tscn") as PackedScene
	test.expect(scene != null, "PauseMenu scene loads.")
	if scene == null:
		return

	var menu := scene.instantiate() as PauseMenu
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(menu)
	var settings := preload("res://app/settings_service.gd").new("user://pause_menu_test_settings.json")
	tree.root.add_child(settings)
	settings.load_and_apply()
	menu.bind_settings(settings)
	test.expect(menu.settings_panel is ScrollContainer, "Settings use a scrollable book page.")
	test.expect(menu.music_volume != null and menu.sfx_volume != null and menu.ui_volume != null, "Settings expose independent music, SFX, and UI volume controls.")
	settings.set_value(&"music_volume", 0.42)
	test.expect_float_close(menu.music_volume.value, 0.42, 0.001, "Audio settings update the bound UI immediately.")

	var bookmark_paths := [
		"DesignRoot/BookmarkSettings",
		"DesignRoot/BookmarkCodex",
		"DesignRoot/BookmarkReturn",
		"DesignRoot/BookmarkBackpack",
		"DesignRoot/BookmarkHelp",
	]
	for path: String in bookmark_paths:
		var button := menu.get_node(path) as TextureButton
		test.expect(button != null, "%s is a TextureButton." % path)
		test.expect(button.texture_normal != null, "%s has normal art." % path)
		test.expect(button.texture_hover != null, "%s has hover art." % path)
		test.expect(button.texture_pressed != null, "%s has pressed art." % path)

	menu.open()
	test.expect(menu.visible, "Opening the pause menu makes it visible.")
	test.expect(tree.paused, "Opening the pause menu pauses the scene tree.")
	var sound_manager := tree.root.get_node_or_null("SoundManager")
	if sound_manager != null:
		sound_manager.play_day_interior_bgm()
		var bgm := sound_manager.get_node("PersistentBGM") as AudioStreamPlayer
		bgm.seek(2.0)
		menu.open()
		test.expect(bgm.playing and bgm.get_playback_position() > 1.0, "Opening an already visible pause menu preserves the persistent BGM position.")
	test.expect(menu.is_opening(), "Pause menu starts its upward reveal animation.")
	test.expect(
		menu.design_root.position.y > menu.get_open_target_position().y,
		"The book starts below its final on-screen position."
	)

	menu.bookmark_codex.pressed.emit()
	test.expect_equal(menu.active_page, PauseMenu.Page.CODEX, "Codex bookmark switches page.")
	menu.bookmark_backpack.pressed.emit()
	test.expect_equal(menu.active_page, PauseMenu.Page.BACKPACK, "Backpack bookmark switches page.")
	test.expect(menu.inventory_page.visible, "Backpack page is visible when its bookmark is selected.")
	menu.bookmark_help.pressed.emit()
	test.expect_equal(menu.active_page, PauseMenu.Page.HELP, "Help bookmark switches page.")
	menu.bookmark_settings.pressed.emit()
	test.expect_equal(menu.active_page, PauseMenu.Page.SETTINGS, "Settings bookmark switches page.")

	menu.bookmark_return.pressed.emit()
	test.expect(not menu.visible, "Return bookmark closes the pause menu.")
	test.expect(not tree.paused, "Return bookmark resumes the scene tree.")
	test.expect(InputMap.has_action("open_backpack"), "Project defines the B-key backpack action.")
	var has_physical_b := InputMap.action_get_events("open_backpack").any(
		func(event: InputEvent) -> bool:
			return event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_B
	)
	test.expect(has_physical_b, "Backpack action is mapped to the physical B key.")
	var backpack_event := InputEventAction.new()
	backpack_event.action = &"open_backpack"
	backpack_event.pressed = true
	menu.open(PauseMenu.Page.SETTINGS)
	menu._unhandled_input(backpack_event)
	test.expect_equal(menu.active_page, PauseMenu.Page.BACKPACK, "B switches an open menu directly to the backpack page.")
	menu._unhandled_input(backpack_event)
	test.expect(not menu.visible and not tree.paused, "Pressing B again while viewing the backpack resumes gameplay.")
	settings.flush()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://pause_menu_test_settings.json"))
	settings.free()
	menu.free()
