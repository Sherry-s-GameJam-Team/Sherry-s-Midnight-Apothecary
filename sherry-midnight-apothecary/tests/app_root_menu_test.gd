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
	var map_switch := app.map_switch
	var fresh_player_data := app.get_player_data()
	test.expect(map_switch.should_show_alignment_tutorial(fresh_player_data), "Home Transformer shows the map-alignment tutorial on first use.")
	fresh_player_data.tutorial_flags[map_switch.ALIGNMENT_TUTORIAL_FLAG] = true
	test.expect(not map_switch.should_show_alignment_tutorial(fresh_player_data), "Completed Transformer alignment tutorials do not replay.")
	test.expect(map_switch.ALIGNMENT_TUTORIAL_TEXT.contains("拖动鼠标") and map_switch.ALIGNMENT_TUTORIAL_TEXT.contains("[W][A][S][D]"), "Transformer tutorial teaches both mouse dragging and WASD panning.")
	test.expect(map_switch.alignment_tutorial_hint != null, "Transformer map owns a visible in-modal alignment hint.")
	test.expect(map_switch.activate_button != null, "Transformer owns an activation control.")
	test.expect_equal(map_switch.activate_button.custom_minimum_size, Vector2(64, 64), "Transformer activation control remains circular.")
	app.menu_controller.state = MenuController.MenuState.FINISHED
	var backpack_event := InputEventAction.new()
	backpack_event.action = &"open_backpack"
	backpack_event.pressed = true
	app._unhandled_input(backpack_event)
	test.expect(app.pause_menu.visible, "B opens the gameplay pause menu.")
	test.expect_equal(app.pause_menu.active_page, PauseMenu.Page.BACKPACK, "B opens directly on the backpack page.")
	app.pause_menu.close()
	app.free()
