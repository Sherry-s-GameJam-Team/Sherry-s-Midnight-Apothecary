extends RefCounted

const PUZZLE_SCRIPT := preload("res://day/levels/market/sewer/sewer_hydraulic_gate_puzzle.gd")
const SEWER_SCENE := preload("res://day/levels/market/sewer/sewer.tscn")
const FOREST_SCENE := preload("res://day/levels/forest/forest.tscn")


func run(test: TestSupport) -> void:
	var puzzle := PUZZLE_SCRIPT.new() as SewerHydraulicGatePuzzle
	puzzle.use_valve(SewerHydraulicGatePuzzle.Valve.BLUE)
	test.expect_equal(puzzle.pressure, 0, "Steam must not start before the red supply valve.")

	puzzle.use_valve(SewerHydraulicGatePuzzle.Valve.RED)
	puzzle.use_valve(SewerHydraulicGatePuzzle.Valve.BLUE)
	puzzle.use_valve(SewerHydraulicGatePuzzle.Valve.YELLOW)
	puzzle.use_valve(SewerHydraulicGatePuzzle.Valve.YELLOW)
	puzzle.use_valve(SewerHydraulicGatePuzzle.Valve.BLUE)
	puzzle.use_valve(SewerHydraulicGatePuzzle.Valve.YELLOW)
	test.expect_equal(puzzle.pressure, 7, "The documented valve sequence must settle at 7 Bar.")
	test.expect(not puzzle.is_unlocked, "The gate remains locked until flow is set to down.")
	puzzle.use_valve(SewerHydraulicGatePuzzle.Valve.GREEN)
	test.expect(puzzle.is_unlocked, "Correct pressure, ratio, order, and downflow unlock the gate.")
	test.expect(puzzle.is_open, "Successful hydraulic validation opens the gate automatically.")

	var overpressure := PUZZLE_SCRIPT.new() as SewerHydraulicGatePuzzle
	overpressure.use_valve(SewerHydraulicGatePuzzle.Valve.RED)
	overpressure.use_valve(SewerHydraulicGatePuzzle.Valve.BLUE)
	overpressure.use_valve(SewerHydraulicGatePuzzle.Valve.BLUE)
	test.expect_equal(overpressure.pressure, 0, "Pressure above 8 Bar must trigger a reset.")

	var sewer := SEWER_SCENE.instantiate()
	test.expect(sewer.get_node_or_null("HydraulicGatePuzzle") is SewerHydraulicGatePuzzle, "Sewer includes its local hydraulic puzzle controller.")
	test.expect(sewer.get_node_or_null("HydraulicGatePuzzle/WhiteboxMainGate") != null, "Sewer includes the lifting whitebox main gate.")
	var gate_sprite := sewer.get_node_or_null("HydraulicGatePuzzle/WhiteboxMainGate/GateSprite") as Sprite2D
	test.expect(gate_sprite != null, "The main gate has a texture sprite.")
	test.expect_equal(gate_sprite.texture.resource_path, "res://day/levels/market/sewer/gate.png", "The closed gate uses gate.png.")
	var red_valve := sewer.get_node_or_null("HydraulicGatePuzzle/PipeArt/RedValveBody") as Sprite2D
	var blue_valve := sewer.get_node_or_null("HydraulicGatePuzzle/PipeArt/BlueValveBody") as SewerHydraulicInteractable
	var yellow_valve := sewer.get_node_or_null("HydraulicGatePuzzle/PipeArt/YellowValveBody") as SewerHydraulicInteractable
	var pressure_gauge := sewer.get_node_or_null("HydraulicGatePuzzle/PipeArt/CentralPressureGauge") as Sprite2D
	test.expect(red_valve is SewerHydraulicInteractable, "The red valve body owns the interaction script and collision-box prompt.")
	test.expect_equal(blue_valve.valve, SewerHydraulicGatePuzzle.Valve.BLUE, "The blue valve body dispatches the blue steam operation.")
	test.expect_equal(yellow_valve.valve, SewerHydraulicGatePuzzle.Valve.YELLOW, "The yellow valve body dispatches the yellow return operation.")
	test.expect(red_valve.get_node_or_null("InteractionArea") is Area2D, "The red valve has an editor-visible interaction box.")
	test.expect(blue_valve.get_node_or_null("InteractionArea") is Area2D, "The blue valve has an editor-visible interaction box.")
	test.expect(yellow_valve.get_node_or_null("InteractionArea") is Area2D, "The yellow valve has an editor-visible interaction box.")
	test.expect_equal(pressure_gauge.texture.resource_path, "res://day/levels/market/sewer/CENTRAL PRESSURE GAUGE& INDICATOR MODULE.png", "The pressure gauge uses the scene art module.")
	test.expect(sewer.get_node_or_null("HydraulicGatePuzzle/PipeArt/DirectionValve") is SewerHydraulicInteractable, "The editor-visible direction sprite owns its interaction script.")
	test.expect(sewer.get_node_or_null("HydraulicGatePuzzle/PipeArt/CentralPressureGauge/GaugePointer") is Sprite2D, "The gauge uses the supplied pointer sprite.")
	var forest_portal := sewer.get_node_or_null("WorldBounds/ForestExitPortal") as DoorPortal
	test.expect(forest_portal != null, "Touching the sewer's right boundary uses an explicit forest exit portal.")
	test.expect_equal(forest_portal.destination_level, &"forest", "The sewer exit transitions through DayRuntime to the forest level.")
	test.expect_equal(forest_portal.destination_entry_id, &"from_sewer", "The sewer exit supplies the forest arrival entry point.")
	test.expect(forest_portal.trigger_on_touch, "The forest exit triggers on contact rather than requiring another key press.")
	var forest := FOREST_SCENE.instantiate()
	test.expect(forest.get_node_or_null("EntryPoints/from_sewer") is Marker2D, "Forest has an entry marker for the sewer handoff and its day-one intro.")
