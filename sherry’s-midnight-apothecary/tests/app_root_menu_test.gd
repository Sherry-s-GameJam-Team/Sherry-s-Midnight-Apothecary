extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://app/app_root.tscn") as PackedScene
	test.expect(scene != null, "AppRoot with the menu loads.")
	if scene == null:
		return
	var app := scene.instantiate() as AppRoot
	app.start_automatically = false
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(app)
	test.expect(is_instance_valid(app.menu_controller), "AppRoot owns the menu controller on startup.")
	test.expect(app.game_flow.current_runtime == null, "AppRoot does not start DayRuntime behind the menu.")
	test.expect(not app.global_ui.visible, "Gameplay UI stays hidden while the menu is active.")
	app.free()
