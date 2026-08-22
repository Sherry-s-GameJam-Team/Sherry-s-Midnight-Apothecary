extends RefCounted


static func run(test: TestSupport) -> void:
	var lake_scene := load("res://day/levels/lake_bottom/lake.tscn") as PackedScene
	test.expect(lake_scene != null, "Lake Bottom scene loads with the Tide Eye encounter.")
	if lake_scene != null:
		var lake := lake_scene.instantiate()
		var boss := lake.get_node_or_null("boss") as CanvasItem
		var tide_eye := lake.get_node_or_null("boss/TideEye")
		var generator := lake.get_node_or_null("boss/BoxGenerator")
		test.expect(boss != null and not boss.visible, "Boss support container starts hidden outside tide_eye_arena.")
		test.expect(tide_eye is TideEye, "Boss uses the TideEye script-rendered node.")
		test.expect(tide_eye != null, "Ground-impact potion listener has a Tide Eye target.")
		test.expect(generator != null and generator.has_method("activate") and generator.has_method("deactivate"), "Boss box generator is phase-controlled.")
		if tide_eye is TideEye:
			test.expect_equal((tide_eye as TideEye).hits_required, 3, "Tide Eye requires exactly three effective hits.")
			test.expect_equal((tide_eye as TideEye).exposed_seconds, 4.2, "Each exposed Tide Eye window lasts 4.2 seconds.")
			var source := (tide_eye as TideEye).get_script().source_code
			test.expect("func _draw" in source, "Tide Eye visual is drawn by GDScript.")
			test.expect(not ("Shader" in source or "SpriteFrames" in source or "Texture2D" in source), "Tide Eye script does not depend on boss textures, frames, or shaders.")
		lake.free()

	var chamber_scene := load("res://day/levels/lake_bottom/gate_chamber.tscn") as PackedScene
	test.expect(chamber_scene != null, "Gate Chamber scene loads.")
	if chamber_scene != null:
		var chamber := chamber_scene.instantiate()
		test.expect(chamber.get_node_or_null("EntryPoints/from_home") is Marker2D, "Gate Chamber has a Home travel arrival point.")
		var door := chamber.get_node_or_null("CentralGateDoor") as GateChamberDoor
		test.expect(door != null and door.destination_level == &"home", "Maintenance station central gate returns to Home.")
		chamber.free()

	var map_scene := load("res://day/interactables/map_switch/data/map.tscn") as PackedScene
	if map_scene != null:
		var map := map_scene.instantiate()
		var anchor := map.get_node_or_null("AnchorPoints/Anchor04") as MapSwitchAnchor
		test.expect(anchor != null and anchor.destination_id == &"gate_chamber", "Anchor04 routes to the maintenance station.")
		map.free()
