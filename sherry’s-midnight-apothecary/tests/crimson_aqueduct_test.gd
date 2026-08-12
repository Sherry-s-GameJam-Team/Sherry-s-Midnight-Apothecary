extends RefCounted

const ROOT_SCENE := preload("res://minigames/crimson_aqueduct/scenes/crimson_aqueduct_root.tscn")


static func run(test: TestSupport) -> void:
	_test_scenes(test)
	_test_config(test)
	_test_valve(test)
	_test_topologies(test)
	_test_network_response(test)
	_test_known_solutions(test)


static func _test_scenes(test: TestSupport) -> void:
	for path: String in [
		"res://minigames/crimson_aqueduct/scenes/crimson_aqueduct_root.tscn",
		"res://minigames/crimson_aqueduct/scenes/interactables/valve_interactable.tscn",
		"res://minigames/crimson_aqueduct/scenes/ui/reservoir_display.tscn",
		"res://minigames/crimson_aqueduct/scenes/ui/ui_hud.tscn",
	]:
		var scene := load(path) as PackedScene
		test.expect(scene != null, "%s loads." % path)
		if scene != null:
			var instance := scene.instantiate()
			test.expect(instance != null, "%s instantiates." % path)
			instance.free()


static func _test_config(test: TestSupport) -> void:
	var root := ROOT_SCENE.instantiate() as CrimsonAqueductRoot
	root.setup({"level_id": "unknown", "time_limit": 2, "purifier_potions": 99, "minimum_pressure": 0.35, "maximum_pressure": 0.7})
	test.expect_equal(root.config["level_id"], &"standard", "Unknown levels fall back to standard.")
	test.expect(not root.config.has("time_limit"), "Legacy time limits are ignored.")
	test.expect(not root.config.has("purifier_potions"), "Legacy potion config is ignored.")
	test.expect_equal(root.config["minimum_pressure"], 0.35, "Minimum pressure is configurable.")
	test.expect_equal(root.config["maximum_pressure"], 0.7, "Maximum pressure is configurable.")
	root.free()


static func _test_valve(test: TestSupport) -> void:
	var scene := load("res://minigames/crimson_aqueduct/scenes/interactables/valve_interactable.tscn") as PackedScene
	var valve := scene.instantiate() as ValveInteractable
	valve.state = ValveInteractable.ValveState.OPEN
	valve.cycle_state()
	test.expect_equal(valve.state, ValveInteractable.ValveState.HALF, "Left click cycles open to half.")
	valve.cycle_state()
	test.expect_equal(valve.state, ValveInteractable.ValveState.CLOSED, "Left click cycles half to closed.")
	valve.cycle_state()
	test.expect_equal(valve.state, ValveInteractable.ValveState.OPEN, "Left click cycles closed to open.")
	test.expect_equal(valve.mouse_filter, Control.MOUSE_FILTER_STOP, "Valve button receives mouse input.")
	valve.free()


static func _test_topologies(test: TestSupport) -> void:
	var expected := {&"tutorial": 6, &"standard": 12, &"hard": 16}
	for level_id: StringName in expected:
		var network := PipeNetwork.new()
		network.configure(level_id)
		test.expect_equal(network.valve_definitions.size(), expected[level_id], "%s has the designed valve count." % level_id)
		test.expect_equal(network.connections.size(), expected[level_id], "%s has one controlled valve per pipe." % level_id)
		for edge: Dictionary in network.connections:
			test.expect(network.node_definitions.has(edge["from"]), "Pipe source exists.")
			test.expect(network.node_definitions.has(edge["to"]), "Pipe destination exists.")
		network.free()


static func _test_network_response(test: TestSupport) -> void:
	var network := PipeNetwork.new()
	network.configure(&"standard")
	var initial := network.settle(220)
	var initial_pollution: float = initial["reservoir_pollution"]
	network.set_valve_state(&"s03", PipeNetwork.STATE_OPENNESS.size() - 1)
	network.set_valve_state(&"s04", PipeNetwork.STATE_OPENNESS.size() - 1)
	network.set_valve_state(&"s09", 0)
	var adjusted := network.settle(220)
	test.expect(float(adjusted["reservoir_pollution"]) < initial_pollution, "Closing pollution feeds lowers the stable pollution value.")
	test.expect(float(adjusted["clean_supply"]) > 0.1, "A clean route still supplies the reservoir.")
	test.expect(network.running, "High pollution never freezes the puzzle.")
	network.free()


static func _test_known_solutions(test: TestSupport) -> void:
	var solutions := {
		&"tutorial": {&"t02": 2, &"t04": 2},
		&"standard": {&"s03": 2, &"s04": 2, &"s11": 2, &"s12": 0},
		&"hard": {&"s03": 2, &"s04": 2, &"s11": 2, &"s12": 0, &"h14": 2, &"h15": 2},
	}
	for level_id: StringName in solutions:
		var network := PipeNetwork.new()
		network.configure(level_id)
		for valve_id: StringName in solutions[level_id]:
			network.set_valve_state(valve_id, solutions[level_id][valve_id])
		var result := network.settle(300)
		test.expect(float(result["reservoir_pollution"]) <= 0.12, "%s has a safe pollution solution." % level_id)
		test.expect(float(result["clean_supply"]) >= 0.25, "%s solution maintains supply." % level_id)
		test.expect(float(result["pressure"]) >= 0.30 and float(result["pressure"]) <= 0.85, "%s solution balances pressure." % level_id)
		network.free()
