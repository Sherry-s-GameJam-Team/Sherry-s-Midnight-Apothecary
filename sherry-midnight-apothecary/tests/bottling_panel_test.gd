extends RefCounted

const BOTTLING_PANEL_SCENE := preload("res://night/alchemy/bottling_panel.tscn")
const POTION_DATA_SCENE := preload("res://shared/definitions/data/potions/red_potion.tres")


static func run(test: TestSupport) -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var panel := BOTTLING_PANEL_SCENE.instantiate() as BottlingPanel
	scene_tree.root.add_child(panel)

	test.expect(panel != null, "BottlingPanel scene instantiates successfully.")

	var mock_potion := POTION_DATA_SCENE.duplicate() as PotionData
	mock_potion.main_effect_id = &"healing"
	mock_potion.display_name = "红色药水"

	var instance_data := {
		"potion_id": "red",
		"quality": 1.30,
		"secondary_effect_id": "speed",
		"secondary_effect_multiplier": 1.25,
		"bottle_style_id": "health"
	}

	# 1. Open for potion
	panel.open_for(mock_potion, instance_data)

	test.expect(panel.visible, "Panel is visible after open_for.")
	test.expect_equal(panel.style_id, &"health", "Initial style defaults to health.")
	test.expect(panel.name_input.text.contains("药水") or panel.name_input.text.contains("药剂"), "Default potion name is automatically populated.")
	test.expect(panel.main_effect_label.text.contains("恢复生命"), "Main effect description is displayed.")
	test.expect(panel.secondary_effect_label.text.contains("提升行动速度"), "Secondary effect description is displayed.")
	test.expect(panel.quality_label.text.contains("卓越"), "Quality label shows appropriate tier name.")

	# 2. Arrow-based switching
	panel._on_next_style_pressed()
	test.expect_equal(panel.style_id, &"heart", "Next arrow switches bottle to heart style.")
	test.expect(panel.style_name_label.text.contains("爱心魔瓶"), "Style name label updates to heart bottle.")

	panel._on_next_style_pressed()
	test.expect_equal(panel.style_id, &"ice", "Next arrow switches bottle to ice style.")

	panel._on_prev_style_pressed()
	test.expect_equal(panel.style_id, &"heart", "Prev arrow switches bottle back to heart style.")

	# 3. Confirmation signal verification
	var confirmed_result := {"emitted": false, "style": &"", "name": ""}
	panel.confirmed.connect(func(s: StringName, n: String) -> void:
		confirmed_result["emitted"] = true
		confirmed_result["style"] = s
		confirmed_result["name"] = n
	)

	panel._on_confirm_pressed()
	test.expect(confirmed_result["emitted"], "Confirming emits confirmed signal.")
	test.expect_equal(confirmed_result["style"], &"heart", "Confirmed signal carries chosen bottle style.")
	test.expect(not confirmed_result["name"].is_empty(), "Confirmed signal carries non-empty potion name.")
	test.expect(not panel.visible, "Panel hides after confirmation.")

	# 4. Auto-stored failure black potion test
	var failed_instance := {
		"potion_id": "black",
		"quality": 0.25,
		"bottle_style_id": "black"
	}
	panel.show_auto_stored(mock_potion, failed_instance)
	test.expect(panel.visible, "Failed potion displays auto stored dialog.")
	test.expect_equal(panel.style_id, &"black", "Style is black for auto stored potion.")
	test.expect(not panel.style_switcher_row.visible, "Style switcher is hidden for black potion.")
	test.expect(not panel.name_row.visible, "Name input is hidden for black potion.")

	panel.free()
