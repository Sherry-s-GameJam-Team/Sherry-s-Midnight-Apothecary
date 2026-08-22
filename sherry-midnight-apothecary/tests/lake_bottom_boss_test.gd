extends RefCounted


static func run(test: TestSupport) -> void:
	var lake_scene := load("res://day/levels/lake_bottom/lake.tscn") as PackedScene
	test.expect(lake_scene != null, "Lake Bottom scene loads with the Tide Eye encounter.")
	if lake_scene != null:
		var lake := lake_scene.instantiate()
		var boss := lake.get_node_or_null("boss") as CanvasItem
		var tide_eye := lake.get_node_or_null("boss/TideEye")
		var generator := lake.get_node_or_null("boss/BoxGenerator")
		var completion_ui := lake.get_node_or_null("TaskCompleteUI") as TaskCompleteUI
		test.expect(boss != null, "Boss support container is present and keeps its editor-authored presentation state.")
		test.expect(completion_ui != null, "Defeating the Tide Eye can present the task-complete UI before departure.")
		test.expect(tide_eye is TideEye, "Boss uses the TideEye script-rendered node.")
		test.expect(tide_eye != null, "Ground-impact potion listener has a Tide Eye target.")
		test.expect(generator != null and generator.has_method("activate") and generator.has_method("deactivate"), "Boss box generator is phase-controlled.")
		if tide_eye is TideEye:
			test.expect_equal((tide_eye as TideEye).hits_required, 3, "Tide Eye requires exactly three effective hits.")
			test.expect_equal((tide_eye as TideEye).exposed_seconds, 4.2, "Each exposed Tide Eye window lasts 4.2 seconds.")
			var source := (tide_eye as TideEye).get_script().source_code
			test.expect("func _draw" in source, "Tide Eye visual is drawn by GDScript.")
			test.expect(not ("Shader" in source or "SpriteFrames" in source or "Texture2D" in source), "Tide Eye script does not depend on boss textures, frames, or shaders.")
		var epilogue_script := load("res://day/levels/lake_bottom/scripts/lake_boss_epilogue.gd") as GDScript
		test.expect(epilogue_script != null and "&\"from_bottom\"" in epilogue_script.source_code, "Tide Eye epilogue routes to the village from_bottom entry.")
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

	var village_scene := load("res://day/levels/golden_cliff/village/village.tscn") as PackedScene
	test.expect(village_scene != null, "Village scene loads for the Tide Eye return.")
	if village_scene != null:
		var village := village_scene.instantiate()
		test.expect(village.get_node_or_null("EntryPoints/from_bottom") is Marker2D, "Tide Eye return places Sherry at the village from_bottom marker.")
		var foreground := village.get_node_or_null("CS") as Parallax2D
		test.expect(foreground != null, "Boat and rope share the village foreground camera layer.")
		var boat := village.get_node_or_null("CS/saved/Boat") as Sprite2D
		test.expect(boat is VillageBoatBob, "The returned boat is stored under saved and has lake-swell motion.")
		var water_loop := village.get_node_or_null("CS/saved/IdleLoop") as AnimatedSprite2D
		test.expect(water_loop != null and water_loop.animation == &"idle_loop", "The dock water idle loop is stored under Village/saved.")
		test.expect(village.get_node_or_null("CS/rope") is Node2D, "Collectable ropes share the boat's foreground camera layer.")
		var lake_return := village.get_node_or_null("LakeReturn") as VillageLakeReturn
		test.expect(lake_return != null and lake_return.dialogue_resource != null, "Village has the Tide Eye reunion dialogue controller.")
		if lake_return != null and lake_return.dialogue_resource != null:
			var dialogue_source := lake_return.dialogue_resource.resource_path
			test.expect(dialogue_source.ends_with("village_lake_return.dialogue"), "Village return controller uses the dock reunion dialogue resource.")
		village.free()
