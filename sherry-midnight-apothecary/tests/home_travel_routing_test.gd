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
		test.expect(town_anchor != null and town_anchor.destination_id == &"market", "Anchor00 routes to the Town level.")
		test.expect(grass_anchor != null and grass_anchor.destination_id == &"grassland", "Anchor01 routes to the Grassland level.")
		test.expect(forest_anchor != null and forest_anchor.destination_id == &"forest_interior", "Anchor02 routes to the Forest Interior level.")
		test.expect(cliff_anchor != null and cliff_anchor.destination_id == &"golden_cliff", "Anchor03 routes to the Golden Cliff level.")
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
		var entrance_portal := cliff.get_node_or_null("Gameplay/EntrancePortal") as DoorPortal
		test.expect(entrance_portal != null, "Golden Cliff has an EntrancePortal under Gameplay.")
		test.expect(entrance_portal != null and entrance_portal.destination_level == &"home" and entrance_portal.destination_entry_id == &"from_cliff", "EntrancePortal routes back to Home.")
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
