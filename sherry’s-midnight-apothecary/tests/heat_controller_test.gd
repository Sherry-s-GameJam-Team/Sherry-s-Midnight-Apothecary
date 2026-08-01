extends RefCounted


static func run(test: TestSupport) -> void:
	var profile := HeatProfileData.new()
	profile.id = &"test"
	profile.ideal_min = 40.0
	profile.ideal_max = 60.0
	profile.warning_min = 30.0
	profile.warning_max = 70.0
	profile.burn_temperature = 80.0
	profile.brew_duration = 2.0
	profile.allowed_burn_seconds = 0.3
	var controller := HeatController.new()
	controller.ambient_temperature = 20.0
	controller.temperature = 20.0
	controller.previous_temperature = 20.0
	controller.cooling_rate = 0.0
	test.expect_float_close(controller.initial_temperature, controller.ambient_temperature, 0.001, "Heat begins at room temperature.")
	test.expect(controller.start_brew(profile), "A valid heat profile starts a timed brew.")
	controller.add_bellows_pump(0.50)
	var before_heat := controller.temperature
	controller.advance(0.5)
	test.expect(controller.fire_power < 0.50, "Fire power decays after a bellows pump.")
	test.expect(controller.temperature > before_heat, "Bellows fire heats the liquid indirectly through thermal physics.")
	controller.simulate(2.0)
	test.expect(controller.state == HeatController.HeatState.FINISHED, "A non-burned timed brew finishes normally.")

	var warmup := HeatController.new()
	warmup.cooling_rate = 0.0
	warmup.heat_gain = 0.0
	warmup.temperature = 20.0
	warmup.previous_temperature = 20.0
	test.expect(warmup.start_brew(profile, false), "Warmup stability test starts independently.")
	warmup.temperature = 30.0
	warmup.advance(0.1)
	test.expect_float_close(warmup.total_temperature_change, 0.0, 0.001, "Initial heating below the ideal range does not count as instability.")
	warmup.temperature = 50.0
	warmup.advance(0.1)
	test.expect(warmup.has_reached_ideal_range, "Stability tracking begins on the first ideal-range sample.")
	test.expect_float_close(warmup.total_temperature_change, 0.0, 0.001, "Entering the ideal range establishes the stability baseline.")
	warmup.temperature = 55.0
	warmup.advance(0.1)
	test.expect_float_close(warmup.total_temperature_change, 5.0, 0.001, "Temperature changes after warmup still affect stability.")

	var burned := HeatController.new()
	burned.cooling_rate = 0.0
	burned.temperature = 90.0
	burned.previous_temperature = 90.0
	test.expect(burned.start_brew(profile), "A second controller can start independently.")
	burned.advance(0.35)
	test.expect(burned.state == HeatController.HeatState.BURNED, "Brief overheating is tolerated, but sustained burn time creates a burned result.")
	controller.free()
	warmup.free()
	burned.free()
