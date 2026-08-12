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
	app.start_new_game(&"home")
	app._on_map_switch_travel_requested(&"grassland", {})
	var day_runtime := app.game_flow.current_runtime as DayRuntime
	test.expect(day_runtime != null and day_runtime.current_level.id == &"grassland", "The map switch deploys Grassland as a registered day level.")
	app.menu_controller.state = MenuController.MenuState.FINISHED
	var backpack_event := InputEventAction.new()
	backpack_event.action = &"open_backpack"
	backpack_event.pressed = true
	app._unhandled_input(backpack_event)
	test.expect(app.pause_menu.visible, "B opens the gameplay pause menu.")
	test.expect_equal(app.pause_menu.active_page, PauseMenu.Page.BACKPACK, "B opens directly on the backpack page.")
	app.pause_menu.close()
	app.free()
