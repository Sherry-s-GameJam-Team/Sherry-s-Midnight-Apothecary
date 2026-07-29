extends RefCounted


static func run(test: TestSupport) -> void:
	test.expect_equal(ProjectSettings.get_setting("application/run/main_scene"), "res://app/app_root.tscn", "AppRoot is the project main scene.")
	test.expect_equal(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280, "Viewport width is 1280.")
	test.expect_equal(ProjectSettings.get_setting("display/window/size/viewport_height"), 720, "Viewport height is 720.")
	test.expect_equal(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "Canvas items stretch mode is enabled.")
	test.expect_equal(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "forward_plus", "Forward Plus is selected.")
	test.expect_equal(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 1, "Nearest texture filtering is selected.")
	var app_scene := load("res://app/app_root.tscn") as PackedScene
	test.expect(app_scene != null, "AppRoot scene can be loaded.")
	if app_scene == null:
		return
	var app_root := app_scene.instantiate()
	test.expect(app_root is AppRoot, "AppRoot scene instantiates the expected script.")
	test.expect(app_root.has_node("GameFlow"), "AppRoot owns GameFlow.")
	test.expect(app_root.has_node("CurrentModeSlot"), "AppRoot owns CurrentModeSlot.")
	app_root.free()
