extends RefCounted


static func run(test: TestSupport) -> void:
	var map_scene := load("res://day/interactables/map_switch/data/map.tscn") as PackedScene
	test.expect(map_scene != null, "The authored Home map anchors load.")
	if map_scene != null:
		var map := map_scene.instantiate()
		var town_anchor := map.get_node_or_null("AnchorPoints/Anchor00") as MapSwitchAnchor
		var grass_anchor := map.get_node_or_null("AnchorPoints/Anchor01") as MapSwitchAnchor
		var forest_anchor := map.get_node_or_null("AnchorPoints/Anchor02") as MapSwitchAnchor
		var cliff_anchor := map.get_node_or_null("AnchorPoints/Anchor03") as MapSwitchAnchor
		var lake_gate_anchor := map.get_node_or_null("AnchorPoints/Anchor04") as MapSwitchAnchor
		var crimson_anchor := map.get_node_or_null("AnchorPoints/Anchor05") as MapSwitchAnchor
		var clock_anchor := map.get_node_or_null("AnchorPoints/Anchor06") as MapSwitchAnchor
		var vesper_anchor := map.get_node_or_null("AnchorPoints/Anchor07") as MapSwitchAnchor
		var crownland_anchor := map.get_node_or_null("AnchorPoints/Anchor08") as MapSwitchAnchor
		var throne_anchor := map.get_node_or_null("AnchorPoints/Anchor09") as MapSwitchAnchor
		test.expect(town_anchor != null and town_anchor.destination_id == &"market", "Anchor00 routes to the Town level.")
		test.expect(grass_anchor != null and grass_anchor.destination_id == &"grassland", "Anchor01 routes to the Grassland level.")
		test.expect(forest_anchor != null and forest_anchor.destination_id == &"forest_interior", "Anchor02 routes to the Forest Interior level.")
		test.expect(cliff_anchor != null and cliff_anchor.destination_id == &"golden_cliff", "Anchor03 routes to the Golden Cliff level.")
		test.expect(lake_gate_anchor != null and lake_gate_anchor.destination_id == &"gate_chamber" and lake_gate_anchor.unlock_day == 2, "Anchor04 is the day-two post-boss Submerged Rest Gate.")
		test.expect(crimson_anchor != null and crimson_anchor.destination_id == &"crimson_vale" and crimson_anchor.unlock_day == 3, "Anchor05 is the day-three post-boss Danxin Gate.")
		test.expect(clock_anchor != null and clock_anchor.destination_id == &"aurem_clockyard" and clock_anchor.unlock_day == 4 and clock_anchor.unlock_flag == &"", "Anchor06 unlocks at the start of day four without a boss flag.")
		test.expect(vesper_anchor != null and vesper_anchor.destination_id == &"vespervale_garden" and vesper_anchor.unlock_day == 5, "Anchor07 is the day-five post-boss Sleeping Village route.")
		test.expect(crownland_anchor != null and crownland_anchor.destination_id == &"crownland" and crownland_anchor.unlock_day == 6, "Anchor08 routes to Crownland on day six.")
		test.expect(throne_anchor != null and throne_anchor.destination_id == &"crownland_boss" and throne_anchor.unlock_day == 6, "Anchor09 routes to the Throne Room on day six.")
		test.expect(map.get_node_or_null("AnchorPoints/Anchor10") == null, "The authored map contains exactly ten route anchors.")
		test.expect(grass_anchor.distance_text.contains("牧人块树") and cliff_anchor.distance_text.contains("索道截风麦"), "Map crop summaries use the harvestables authored in their destination scenes.")
		map.free()
	var map_controller_script := load("res://day/interactables/map_switch/scripts/map_switch_controller.gd") as GDScript
	var map_controller: Object = map_controller_script.new()
	var locked_player_data := PlayerData.new()
	test.expect(map_controller.can_lock_destination({"id": &"market"}, locked_player_data), "The initially unlocked Town anchor can be selected.")
	test.expect(map_controller.can_lock_destination({"id": &"grassland"}, locked_player_data), "The Grassland anchor is unlocked from the start.")
	test.expect(not map_controller.can_lock_destination({"id": &"golden_cliff"}, locked_player_data), "Future locked anchors cannot be confirmed.")
	locked_player_data.unlock_level(&"golden_cliff")
	test.expect(map_controller.can_lock_destination({"id": &"golden_cliff"}, locked_player_data), "An activated future anchor becomes confirmable.")
	locked_player_data.unlock_level(&"forest_interior")
	test.expect(map_controller.can_lock_destination({"id": &"forest_interior"}, locked_player_data), "An activated forest_interior anchor becomes confirmable.")
	var day_four_clock := {"id": &"aurem_clockyard", "scheduled_unlock": true, "unlock_day": 4, "unlock_flag": &""}
	test.expect(not map_controller._meets_scheduled_unlock(day_four_clock, locked_player_data, 3), "The Clocktower Gate remains inactive before day four.")
	test.expect(map_controller._meets_scheduled_unlock(day_four_clock, locked_player_data, 4), "The Clocktower Gate activates at the start of day four.")
	var lake_boss_gate := {"id": &"gate_chamber", "scheduled_unlock": true, "unlock_day": 2, "unlock_flag": &"lake_bottom_tide_eye_defeated", "unlock_flag_source": "event"}
	test.expect(not map_controller._meets_scheduled_unlock(lake_boss_gate, locked_player_data, 2), "The Submerged Rest Gate waits for its boss flag on day two.")
	locked_player_data.set_event_flag(&"lake_bottom_tide_eye_defeated")
	test.expect(map_controller._meets_scheduled_unlock(lake_boss_gate, locked_player_data, 2), "The Submerged Rest Gate activates after its boss is defeated.")
	map_controller.free()
	var interaction_scene := load("res://day/interactables/map_switch/map_switch_interaction.tscn") as PackedScene
	if interaction_scene != null:
		var interaction := interaction_scene.instantiate()
		var confirm_button := interaction.get_node_or_null("ConfirmButton") as Button
		test.expect(confirm_button != null and confirm_button.disabled, "Map includes a disabled confirmation button for inactive anchors.")
		interaction.free()

	var player_data := PlayerData.new()
	var runtime := DayRuntime.new()
	runtime.player_data = player_data
	test.expect(runtime.set_home_destination(&"market"), "Home can lock its initially unlocked Town anchor.")
	test.expect(runtime.set_home_destination(&"grassland"), "Home can lock the default-unlocked Grassland anchor.")
	test.expect(runtime.activate_travel_anchor(&"golden_cliff"), "DayRuntime activates the golden_cliff travel anchor.")
	test.expect(runtime.set_home_destination(&"golden_cliff"), "Home can lock golden_cliff after it is activated.")
	test.expect_equal(player_data.active_home_destination_id, &"golden_cliff", "The selected Home destination is stored in PlayerData.")
	test.expect(runtime.activate_travel_anchor(&"forest_interior"), "DayRuntime activates the forest_interior travel anchor.")
	test.expect(runtime.set_home_destination(&"forest_interior"), "Home can lock forest_interior after it is activated.")
	test.expect_equal(player_data.active_home_destination_id, &"forest_interior", "The selected Forest Interior destination is stored in PlayerData.")
	test.expect(runtime.activate_travel_anchor(&"crownland_boss"), "DayRuntime registers the Throne Room map destination.")
	test.expect(runtime.set_home_destination(&"crownland_boss"), "Home can lock the registered Throne Room route.")
	runtime.free()

	var home_scene := load("res://day/levels/home/home.tscn") as PackedScene
	test.expect(home_scene != null, "Home scene loads for its dynamic exterior door.")
	if home_scene != null:
		var home := home_scene.instantiate()
		var home_door := home.get_node_or_null("Door") as DoorPortal
		test.expect(home_door != null and home_door.use_active_home_destination, "Home exterior door resolves the locked map destination.")
		test.expect(home.get_node_or_null("EntryPoints/from_grass") is Marker2D, "Home has a Grassland-door arrival point.")
		test.expect(home.get_node_or_null("EntryPoints/from_cliff") is Marker2D, "Home has a Golden Cliff-door arrival point.")
		test.expect(home.get_node_or_null("EntryPoints/from_forest") is Marker2D, "Home has a Forest-door arrival point.")
		home.free()

	var town_scene := load("res://day/levels/market/town/town.tscn") as PackedScene
	var grass_scene := load("res://day/levels/grassland/grass.tscn") as PackedScene
	var cliff_scene := load("res://day/levels/golden_cliff/golden_cliff.tscn") as PackedScene
	var forest_scene := load("res://day/levels/forest/forest.tscn") as PackedScene
	var forest_interior_scene := load("res://day/levels/forest/interior/forest_interior.tscn") as PackedScene
	var crownland_scene := load("res://day/levels/crownland/crownland.tscn") as PackedScene
	var throne_scene := load("res://day/levels/crownland/boss.tscn") as PackedScene
	if town_scene != null:
		var town := town_scene.instantiate()
		test.expect(town.get_node_or_null("EntryPoints/from_home") is Marker2D, "Town has a Home-door arrival point.")
		town.free()
	if grass_scene != null:
		var grass := grass_scene.instantiate()
		test.expect(grass.get_node_or_null("EntryPoints/from_home") is Marker2D, "Grassland has a Home-door arrival point.")
		var grass_door := grass.get_node_or_null("HomeDoor") as DoorPortal
		test.expect(grass_door != null and grass_door.destination_level == &"home" and grass_door.destination_entry_id == &"from_grass", "Grassland door returns to Home.")
		grass.free()
	if cliff_scene != null:
		var cliff := cliff_scene.instantiate()
		test.expect(cliff.get_node_or_null("EntryPoints/from_home") is Marker2D, "Golden Cliff has a Home-door arrival point.")
		test.expect(cliff.get_node_or_null("Gameplay/EntrancePortal") == null, "Golden Cliff omits the left-side E-key return-to-Home interaction.")
		cliff.free()
	if forest_scene != null:
		var forest := forest_scene.instantiate()
		test.expect(forest.get_node_or_null("EntryPoints/restored_return") is Marker2D, "Forest has a restored_return arrival point.")
		forest.free()
	if forest_interior_scene != null:
		var interior := forest_interior_scene.instantiate()
		test.expect(interior.get_node_or_null("EntryPoints/from_home") is Marker2D, "Forest Interior has a Home arrival point.")
		var home_door := interior.get_node_or_null("HomeDoor") as DoorPortal
		test.expect(home_door != null and home_door.destination_level == &"home" and home_door.destination_entry_id == &"from_forest", "Forest Interior HomeDoor routes back to Home.")
		var forest_return := interior.get_node_or_null("ForestReturnDoor") as DoorPortal
		test.expect(forest_return != null and forest_return.destination_level == &"forest" and forest_return.destination_entry_id == &"restored_return", "Forest Interior ForestReturnDoor routes back to forest restored_return.")
		interior.free()
	if crownland_scene != null:
		var crownland := crownland_scene.instantiate()
		test.expect(crownland.get_node_or_null("EntryPoints/from_home") is Marker2D, "Crownland has a Home-map arrival point.")
		crownland.free()
	if throne_scene != null:
		var throne := throne_scene.instantiate()
		test.expect(throne.get_node_or_null("EntryPoints/from_home") is Marker2D, "The Throne Room has a Home-map arrival point.")
		throne.free()
