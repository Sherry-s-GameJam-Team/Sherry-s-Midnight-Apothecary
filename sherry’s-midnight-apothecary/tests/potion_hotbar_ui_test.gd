extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://shared/potions/ui/potion_hotbar.tscn") as PackedScene
	test.expect(scene != null, "Potion hotbar scene loads.")
	if scene == null:
		return
	var hotbar := scene.instantiate() as PotionHotbar
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(hotbar)
	test.expect((hotbar.get_node("UI") as Control).visible, "Potion hotbar UI is visible in gameplay.")
	var player := PlayerData.new()
	player.potions = {
		&"red_potion": [{
			"instance_uid": "hotbar-red",
			"remaining_dose": 0.4,
			"quality": 1.0,
			"potency": 1.0,
		}],
	}
	test.expect(player.equip_potion(0, &"red_potion"), "Test potion equips into the first slot.")
	var service := PotionInventoryService.new(player)
	service.setup(player)
	var red: PotionData = load("res://shared/definitions/data/potions/red_potion.tres")
	hotbar.setup(service, {red.id: red}, 0.25)

	test.expect(hotbar._slots is VBoxContainer, "Potion hotbar slots use a left-side vertical container.")
	test.expect_float_close(hotbar._slots.anchor_left, 0.0, 0.001, "Potion hotbar is anchored to the left edge.")
	test.expect_equal(hotbar._slot_buttons.size(), 3, "Only unlocked potion slot buttons are active.")
	var first_slot := hotbar._slot_views[0]
	test.expect(first_slot.is_equipped, "Equipped potion slot uses its active circular presentation.")
	test.expect_float_close(first_slot.capacity_ratio, 0.4, 0.001, "Capacity ring matches the current bottle dose.")
	test.expect(first_slot.bottle_texture != null and first_slot.button.icon != null, "Circular slot renders the shared SVG glass bottle.")
	test.expect(first_slot.bottle_view.material is ShaderMaterial, "Bottle art uses an explicit circular mask shader.")
	test.expect_equal(first_slot.dose_label.text, "40%", "Capacity percentage matches the bottle and ring.")
	var empty_slot := hotbar._slot_views[1]
	test.expect(not empty_slot.is_equipped, "Unequipped potion slot uses its empty state.")
	test.expect(empty_slot.bottle_texture != null, "Unequipped slot still displays a darkened glass bottle.")
	test.expect_equal(empty_slot.dose_label.text, "空", "Unequipped slot is labelled as empty.")

	player.potions[&"red_potion"][0]["remaining_dose"] = 0.18
	hotbar._refresh_slots()
	test.expect_float_close(first_slot.capacity_ratio, 0.18, 0.001, "Capacity ring refreshes when potion dose changes.")
	test.expect_equal(first_slot.dose_label.text, "18%", "Capacity percentage refreshes with the ring.")
	hotbar.free()
