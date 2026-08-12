extends RefCounted

const ROOT_SCENE := preload("res://minigames/crimson_aqueduct/scenes/crimson_aqueduct_root.tscn")


static func run(test: TestSupport) -> void:
	_test_scenes(test)
	_test_config(test)
	_test_interactables(test)
	_test_network(test)
	_test_pollution_has_no_failure_state(test)


static func _test_scenes(test: TestSupport) -> void:
	for path: String in [
		"res://minigames/crimson_aqueduct/scenes/crimson_aqueduct_root.tscn",
		"res://minigames/crimson_aqueduct/scenes/interactables/valve_interactable.tscn",
		"res://minigames/crimson_aqueduct/scenes/interactables/diverter_interactable.tscn",
		"res://minigames/crimson_aqueduct/scenes/interactables/purifier_interactable.tscn",
		"res://minigames/crimson_aqueduct/scenes/interactables/crack_interactable.tscn",
		"res://minigames/crimson_aqueduct/scenes/ui/reservoir_display.tscn",
		"res://minigames/crimson_aqueduct/scenes/ui/ui_hud.tscn",
	]:
		var scene := load(path) as PackedScene
		test.expect(scene != null, "%s loads." % path)
		if scene != null:
			var instance := scene.instantiate()
			test.expect(instance != null, "%s instantiates." % path)
			_assert_no_3d_or_player(test, instance)
			instance.free()


static func _assert_no_3d_or_player(test: TestSupport, node: Node) -> void:
	test.expect(not node is Node3D, "%s is not a 3D node." % node.name)
	test.expect(str(node.name).to_lower() != "player", "%s is not a player node." % node.name)
	for child in node.get_children():
		_assert_no_3d_or_player(test, child)


static func _test_config(test: TestSupport) -> void:
	var root := ROOT_SCENE.instantiate() as CrimsonAqueductRoot
	root.setup({"level_id": "unknown", "time_limit": -4, "pollution_fail_threshold": 0.1, "purifier_potions": -2})
	test.expect_equal(root.config["level_id"], &"standard", "Unknown levels fall back to standard.")
	test.expect(not root.config.has("time_limit"), "Legacy time limits are ignored.")
	test.expect(not root.config.has("pollution_fail_threshold"), "Pollution no longer creates a failure state.")
	test.expect_equal(root.config["purifier_potions"], 0, "Potion counts cannot be negative.")
	root.setup({"level_id": &"hard", "sealant_potions": 7})
	test.expect_equal(root.config["level_id"], &"hard", "Hard layout is accepted.")
	test.expect_equal(root.config["sealant_potions"], 7, "Config overrides potion inventory.")
	root.free()


static func _test_interactables(test: TestSupport) -> void:
	var valve := ValveInteractable.new()
	valve.state = ValveInteractable.ValveState.OPEN
	valve.cycle_state()
	test.expect_equal(valve.get_openness(), 0.5, "Valve cycles from open to half.")
	valve.cycle_state()
	test.expect_equal(valve.get_openness(), 0.0, "Valve cycles from half to closed.")
	valve.cycle_state()
	test.expect_equal(valve.get_openness(), 1.0, "Valve cycles from closed to open.")
	valve.free()

	var mouse := FPMouseController.new()
	mouse.set_mode(FPMouseController.MODE_PURIFIER)
	test.expect_equal(mouse.current_mode, &"purifier", "Mouse controller selects a potion mode.")
	mouse.cancel()
	test.expect_equal(mouse.current_mode, &"none", "Mouse controller cancels the potion mode.")
	mouse.free()


static func _test_network(test: TestSupport) -> void:
	var network := PipeNetwork.new()
	network.configure(&"tutorial")
	for index in 60:
		network.advance(0.1)
	var open_supply := network.clean_supply
	test.expect(open_supply > 0.1, "Open pipes carry clean water to the reservoir.")
	network.set_valve_state(&"town_gate", 0.0)
	for index in 80:
		network.advance(0.1)
	test.expect(network.clean_supply < open_supply, "A closed town valve reduces reservoir supply.")
	test.expect(network.seal_crack(&"upper_crack"), "An open crack can be sealed.")
	test.expect(not network.seal_crack(&"upper_crack"), "A crack cannot consume sealant twice.")
	test.expect(network.activate_purifier(&"purifier_basin"), "The purifier can be activated.")
	network.configure(&"hard")
	test.expect(network.cracks.has(&"lower_crack"), "Hard mode adds the lower crack.")
	network.free()


static func _test_pollution_has_no_failure_state(test: TestSupport) -> void:
	var root := ROOT_SCENE.instantiate() as CrimsonAqueductRoot
	root.setup({"safe_pollution_threshold": 0.0, "stability_duration": 999.0})
	root.pipe_network = PipeNetwork.new()
	root.pipe_network.reservoir_pollution = 1.0
	test.expect(not root._finished, "High pollution does not finish or freeze the puzzle.")
	test.expect(root.has_signal("minigame_failed"), "Compatibility failure signal remains available to hosts.")
	root.pipe_network.free()
	root.free()
