extends RefCounted

const BREWING_PANEL_SCENE := preload("res://night/alchemy/brewing_panel.tscn")


static func run(test: TestSupport) -> void:
	var brewing_panel := BREWING_PANEL_SCENE.instantiate()
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(brewing_panel)
	var scene_control := brewing_panel.get_node("ArtBoard/BellowsControl") as BellowsControl
	test.expect(scene_control != null, "Brewing scene contains BellowsControl.")
	test.expect(scene_control.bellows_sprite_sheet != null, "Brewing scene explicitly binds the bellows sprite sheet.")
	test.expect_equal(scene_control.sprite_frame_count, 15, "Brewing scene configures all bellows sprite frames.")
	test.expect_float_close(scene_control.pump_cycle_duration, 0.32, 0.001, "Brewing scene uses the rapid pump duration.")
	test.expect(scene_control.sprite_flip_horizontal, "Brewing scene mirrors the bellows sprite horizontally.")
	brewing_panel.free()

	var control := BellowsControl.new()
	scene_tree.root.add_child(control)
	control.size = Vector2(320.0, 180.0)

	test.expect(control.bellows_sprite_sheet != null, "Bellows loads its generated sprite sheet.")
	test.expect_equal(control.sprite_frame_count, 15, "Bellows uses the 15-frame press-and-return cycle.")
	test.expect_equal(control._sprite_frame_index(), 0, "Bellows starts from the expanded frame.")

	var click_strengths: Array[float] = []
	control.bellows_pumped.connect(func(strength: float) -> void: click_strengths.append(strength))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	control._gui_input(click)
	test.expect_equal(click_strengths.size(), 1, "One left click completes one bellows pump.")
	control._gui_input(click)
	test.expect_equal(click_strengths.size(), 1, "Repeated clicks are ignored during the pump animation.")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	control._gui_input(release)
	test.expect_equal(click_strengths.size(), 1, "Releasing the mouse does not trigger another pump.")
	control._process(control.pump_cycle_duration)
	control._gui_input(click)
	test.expect_equal(click_strengths.size(), 2, "A new click pumps again after the animation returns.")
	control._process(control.pump_cycle_duration)

	control.pump_for_test()
	test.expect(control._pump_cycle_active, "One bellows pump starts one complete sprite cycle.")
	control._process(control.pump_cycle_duration * 0.5)
	test.expect(control._sprite_frame_index() >= 7, "The midpoint of the cycle reaches the compressed bellows frame.")
	control._process(control.pump_cycle_duration * 0.6)
	test.expect(not control._pump_cycle_active, "The sprite cycle returns to idle after its accelerated duration.")
	test.expect_equal(control._sprite_frame_index(), 0, "Bellows returns to the expanded idle frame.")

	var sustained_strengths: Array[float] = []
	control.bellows_pumped.connect(func(strength: float) -> void: sustained_strengths.append(strength))
	control.bellows_fatigue = 0.0
	for pump_index in 12:
		control.pump_for_test()
		control._process(control.pump_cycle_duration)
	test.expect_equal(sustained_strengths.size(), 12, "A full return cycle allows every sustained bellows stroke.")
	test.expect(
		sustained_strengths[-1] >= control.bellows_strength * 0.85,
		"Late sustained pumping retains at least 85% of the initial fire contribution.",
	)
	test.expect(control.bellows_fatigue < 0.5, "Bellows recovery prevents fatigue from saturating during valid return cycles.")

	control.bellows_fatigue = 1.0
	control.set_pumping_enabled(false)
	control.set_pumping_enabled(true)
	test.expect_float_close(control.bellows_fatigue, 0.0, 0.001, "A new brew starts with a fully refilled bellows.")

	var sustained_heat := HeatController.new()
	sustained_heat.temperature = 65.0
	sustained_heat.previous_temperature = 65.0
	sustained_heat.maximum_temperature = 95.0
	var sustained_profile := HeatProfileData.new()
	sustained_profile.id = &"sustained_bellows_test"
	sustained_profile.burn_temperature = 100.0
	sustained_profile.brew_duration = 60.0
	test.expect(sustained_heat.start_brew(sustained_profile, false), "Sustained bellows integration starts a long brew.")
	control.bellows_pumped.connect(sustained_heat.add_bellows_pump)
	var initial_temperature := sustained_heat.temperature
	for pump_index in 12:
		control.pump_for_test()
		control._process(0.5)
		sustained_heat.advance(0.5)
	test.expect(sustained_heat.fire_power >= 0.70, "Late-brew pumping maintains a strong fire instead of collapsing between strokes.")
	test.expect(sustained_heat.temperature >= initial_temperature, "Sustained late-brew pumping overcomes high-temperature cooling.")
	sustained_heat.free()
	control.free()
