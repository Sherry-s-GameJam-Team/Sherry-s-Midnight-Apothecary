extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://night/ui/pause_menu/pause_menu.tscn") as PackedScene
	test.expect(scene != null, "PauseMenu scene loads.")
	if scene == null:
		return

	var menu := scene.instantiate() as PauseMenu
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(menu)

	var bookmark_paths := [
		"DesignRoot/BookmarkSettings",
		"DesignRoot/BookmarkCodex",
		"DesignRoot/BookmarkReturn",
		"DesignRoot/BookmarkNotes",
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
	test.expect(menu.is_opening(), "Pause menu starts its upward reveal animation.")
	test.expect(
		menu.design_root.position.y > menu.get_open_target_position().y,
		"The book starts below its final on-screen position."
	)

	menu.bookmark_codex.pressed.emit()
	test.expect_equal(menu.active_page, PauseMenu.Page.CODEX, "Codex bookmark switches page.")
	menu.bookmark_notes.pressed.emit()
	test.expect_equal(menu.active_page, PauseMenu.Page.NOTES, "Notes bookmark switches page.")
	menu.bookmark_help.pressed.emit()
	test.expect_equal(menu.active_page, PauseMenu.Page.HELP, "Help bookmark switches page.")
	menu.bookmark_settings.pressed.emit()
	test.expect_equal(menu.active_page, PauseMenu.Page.SETTINGS, "Settings bookmark switches page.")

	menu.bookmark_return.pressed.emit()
	test.expect(not menu.visible, "Return bookmark closes the pause menu.")
	test.expect(not tree.paused, "Return bookmark resumes the scene tree.")
	menu.free()
