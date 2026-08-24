extends RefCounted


static func run(test: TestSupport) -> void:
	var before_boss := PlayerData.new()
	test.expect(ForestDayOneEnzuoIntro.should_trigger_from_sewer(1, false, false, false), "The first sewer-to-forest arrival starts the forest opening.")
	test.expect(not ForestDayOneEnzuoIntro.should_trigger_from_sewer(1, true, false, false), "The sewer opening does not replay after completion.")
	test.expect(not ForestDayOneEnzuoIntro.should_trigger_from_sewer(2, false, false, false), "The sewer opening belongs to day one.")
	test.expect(ForestDayOneEnzuoIntro.should_show(1, before_boss), "The suspended Enzuo issue appears during the day-one forest route.")
	test.expect(not ForestDayOneEnzuoIntro.should_show(2, before_boss), "The suspended Enzuo issue is hidden outside the day-one forest route.")
	test.expect(not ForestEnzuoSavedInteraction.should_show(1, before_boss), "The fallen Enzuo interaction waits for Boss completion.")
	before_boss.tutorial_flags[&"forest_completed"] = true
	test.expect(not ForestDayOneEnzuoIntro.should_show(1, before_boss), "Boss completion hides the suspended Enzuo issue.")
	test.expect(ForestEnzuoSavedInteraction.should_show(1, before_boss), "Boss completion activates Enzuofall on day one.")
	before_boss.set_event_flag(&"save_enzuo_solved")
	test.expect(not ForestEnzuoSavedInteraction.should_show(1, before_boss), "The solved Enzuo interaction is hidden permanently.")
