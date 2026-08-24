extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://night/ui/pause_menu/pause_inventory_page.tscn") as PackedScene
	test.expect(scene != null, "Pause inventory page scene loads.")
	if scene == null:
		return
	var page := scene.instantiate() as PauseInventoryPage
	test.expect(page.story_item_definitions.any(func(item: StoryItemData) -> bool: return item != null and item.id == &"springburst_potion_commission"), "Backpack registers the Springburst commission story item definition.")
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(page)
	var player := PlayerData.new()
	player.inventory = {&"herdsmans_loaf_bush": 3}
	player.potions = {
		&"red_potion": [{"instance_uid": "red-one", "remaining_dose": 1.0, "quality": 1.0}],
		&"black_potion": [{"instance_uid": "failed-one", "remaining_dose": 1.0, "quality": 0.5}],
	}
	player.unlock_throwable_potion(&"red_potion")
	player.add_story_item(&"sealed_letter")
	page.bind_player_data(player)

	test.expect_equal(page.get_visible_slot_count(), 4, "Three unlocked slots plus the next locked slot are visible.")
	page.select_potion(&"black_potion")
	test.expect_equal(page.selected_potion_id, &"", "Black potion cannot be selected for loading.")
	page.select_potion(&"red_potion")
	page.equip_selected_to_slot(0)
	test.expect_equal(player.equipped_potion_ids[0], &"red_potion", "Selected potion loads into the requested slot.")
	page.select_potion(&"red_potion")
	page.equip_selected_to_slot(2)
	test.expect_equal(player.equipped_potion_ids, [&"", &"", &"red_potion"], "Loading an equipped potion into another slot moves it.")

	player.potions[&"purification_potion"] = [{"instance_uid": "tutorial-purification", "remaining_dose": 1.0, "quality": 1.0}]
	player.unlock_throwable_potion(&"purification_potion")
	page.refresh()
	var selected := {"id": StringName()}
	var equipped := {"slot": -1, "id": StringName()}
	page.potion_selected.connect(func(potion_id: StringName) -> void: selected.id = potion_id)
	page.potion_equipped.connect(func(slot_index: int, potion_id: StringName) -> void:
		equipped.slot = slot_index
		equipped.id = potion_id
	)
	page.begin_potion_equip_tutorial(&"purification_potion")
	test.expect(page.is_potion_equip_tutorial_active(), "Potion equip tutorial can highlight an inventory potion.")
	test.expect(page.get_potion_button(&"purification_potion") != null, "Tutorial exposes the purification potion button.")
	page.select_potion(&"purification_potion")
	test.expect_equal(selected.id, &"purification_potion", "Selecting the tutorial potion emits its selection signal.")
	test.expect(page.get_slot_button(0) != null, "Tutorial exposes an unlocked loadout slot button.")
	page.equip_selected_to_slot(0)
	test.expect_equal(equipped, {"slot": 0, "id": &"purification_potion"}, "Equipping the tutorial potion emits slot and potion details.")
	page.end_potion_equip_tutorial()
	test.expect(not page.is_potion_equip_tutorial_active(), "Potion equip tutorial presentation can be cleared.")

	player.unlock_potion_slot(PlayerData.MAX_POTION_SLOT_COUNT)
	page.refresh()
	test.expect_equal(page.get_visible_slot_count(), 8, "At maximum capacity exactly eight slots are visible.")
	page.show_items()
	test.expect(page.item_panel.visible and not page.potion_panel.visible, "Item secondary menu replaces the potion panel.")
	test.expect(page.material_entries.get_child_count() == 1, "Held alchemy materials appear in the item list.")
	test.expect(page.story_entries.get_child_count() == 1, "Unknown future story items appear using fallback presentation.")
	page.free()
