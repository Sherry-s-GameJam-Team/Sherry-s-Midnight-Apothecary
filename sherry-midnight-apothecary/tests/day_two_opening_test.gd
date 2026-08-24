extends RefCounted


static func run(test: TestSupport) -> void:
	var bedroom_scene := load("res://day/levels/home/bedroom.tscn") as PackedScene
	test.expect(bedroom_scene != null, "Bedroom with the day-two opening loads.")
	if bedroom_scene == null:
		return
	var bedroom := bedroom_scene.instantiate()
	var opening := bedroom.get_node_or_null("DayTwoOpening") as DayTwoOpening
	test.expect(opening != null, "Bedroom installs the day-two opening controller.")
	test.expect(opening != null and opening.dialogue_resource != null, "Day-two opening has an assigned Dialogue Manager resource.")
	test.expect(opening != null and opening.layer < 100, "Day-two artwork renders below the dialogue balloon.")
	bedroom.free()

	var data := PlayerData.new()
	test.expect(DayTwoOpening.should_present(2, data), "A fresh internal day two presents the opening.")
	test.expect(not DayTwoOpening.should_present(1, data), "Day one skips the day-two opening.")
	data.set_event_flag(DayTwoOpening.COMPLETE_FLAG)
	test.expect(not DayTwoOpening.should_present(2, data), "The completion flag prevents replay.")

	var dialogue_source := FileAccess.get_file_as_string("res://day/levels/home/day_two_opening.dialogue")
	var opening_source := FileAccess.get_file_as_string("res://day/levels/home/day_two_opening.gd")
	test.expect(not opening_source.contains("SHERRY_TEXTURE"), "Day-two background staging does not duplicate Sherry's dialogue portrait.")
	test.expect(not opening_source.contains("LUCA_TEXTURE"), "Day-two background staging does not duplicate Luca's dialogue portrait.")
	test.expect(not opening_source.contains("ENZUO_TEXTURE"), "Day-two background staging does not duplicate Enzuo's dialogue portrait.")
	test.expect(opening_source.contains("grant_story_bottles"), "Day-two opening stores Springburst bottles as story items.")
	test.expect(not opening_source.contains("add_brewed_potion"), "Day-two opening does not unlock the throwable cyan potion early.")
	test.expect(opening_source.contains("set_event_flag(SUPPLY_FLAG)"), "Day-two opening unlocks remote supply before departing for Golden Cliff.")
	test.expect(opening_source.contains("_play_white_transition"), "Day-two departure uses the dedicated white transition.")
	test.expect(not opening_source.contains("主线任务："), "Day-two transition does not render a task-description card.")
	test.expect(not opening_source.contains("transition_to_level_with_blackout"), "Day-two departure does not place a black transition over the white screen.")
	for required_event in [
		"day2_doorway",
		"day2_letter",
		"day2_downstairs",
		"day2_supply_tutorial",
		"day2_mixing_tutorial",
		"day2_morning_light",
	]:
		test.expect(dialogue_source.contains(required_event), "Day-two script includes the %s visual cue." % required_event)
	test.expect(dialogue_source.contains("=> END"), "Day-two dialogue has a finite ending.")
	var bridge_source := FileAccess.get_file_as_string("res://menu/transition/bedroom_intro_bridge.gd")
	test.expect(bridge_source.contains("DayTwoOpening"), "The menu bedroom bridge prioritizes the day-two story opening over the generic wake animation.")
