extends RefCounted

const PUZZLE_SCRIPT := preload("res://day/levels/market/sewer/sewer_hydraulic_gate_puzzle.gd")
const SEWER_SCENE := preload("res://day/levels/market/sewer/sewer.tscn")


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
	test.expect_equal(puzzle.pressure, 6, "The documented valve sequence must settle at 6 Bar.")
	test.expect(not puzzle.is_unlocked, "The gate remains locked until flow is set to down.")
	puzzle.use_valve(SewerHydraulicGatePuzzle.Valve.GREEN)
	test.expect(puzzle.is_unlocked, "Correct pressure, ratio, order, and downflow unlock the gate.")

	var overpressure := PUZZLE_SCRIPT.new() as SewerHydraulicGatePuzzle
	overpressure.use_valve(SewerHydraulicGatePuzzle.Valve.RED)
	overpressure.use_valve(SewerHydraulicGatePuzzle.Valve.BLUE)
	overpressure.use_valve(SewerHydraulicGatePuzzle.Valve.BLUE)
	test.expect_equal(overpressure.pressure, 0, "Pressure above 8 Bar must trigger a reset.")
	overpressure.use_valve(SewerHydraulicGatePuzzle.Valve.RED)
	overpressure.use_valve(SewerHydraulicGatePuzzle.Valve.RESET)
	test.expect_equal(overpressure.pressure, 0, "The reset control returns the system to 0 Bar.")

	var sewer := SEWER_SCENE.instantiate()
	test.expect(sewer.get_node_or_null("HydraulicGatePuzzle") is SewerHydraulicGatePuzzle, "Sewer includes its local hydraulic puzzle controller.")
	test.expect(sewer.get_node_or_null("HydraulicGatePuzzle/WhiteboxMainGate") != null, "Sewer includes the lifting whitebox main gate.")
	var gate_sprite := sewer.get_node_or_null("HydraulicGatePuzzle/WhiteboxMainGate/GateSprite") as Sprite2D
	test.expect(gate_sprite != null, "The main gate has a texture sprite.")
	test.expect_equal(gate_sprite.texture.resource_path, "res://day/levels/market/sewer/gate.png", "The closed gate uses gate.png.")
	var red_wheel := sewer.get_node_or_null("HydraulicGatePuzzle/PipeArt/RedWheel") as Sprite2D
	var pressure_gauge := sewer.get_node_or_null("HydraulicGatePuzzle/PipeArt/CentralPressureGauge") as Sprite2D
	test.expect_equal(red_wheel.texture.resource_path, "res://day/levels/market/sewer/red_wheel.png", "The red valve uses its scene art wheel.")
	test.expect_equal(pressure_gauge.texture.resource_path, "res://day/levels/market/sewer/CENTRAL PRESSURE GAUGE& INDICATOR MODULE.png", "The pressure gauge uses the scene art module.")
