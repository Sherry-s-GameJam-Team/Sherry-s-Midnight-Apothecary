extends RefCounted


static func run(test: TestSupport) -> void:
	var before_boss := PlayerData.new()
	test.expect(ForestDayOneEnzuoIntro.should_show(2, before_boss), "The suspended Enzuo issue appears on day two before the Boss is defeated.")
	test.expect(not ForestDayOneEnzuoIntro.should_show(1, before_boss), "The suspended Enzuo issue is hidden before day two.")
	test.expect(not ForestEnzuoSavedInteraction.should_show(2, before_boss), "The fallen Enzuo interaction waits for Boss completion.")
	before_boss.tutorial_flags[&"forest_completed"] = true
	test.expect(not ForestDayOneEnzuoIntro.should_show(2, before_boss), "Boss completion hides the suspended Enzuo issue.")
	test.expect(ForestEnzuoSavedInteraction.should_show(2, before_boss), "Boss completion activates Enzuofall on day two.")
	before_boss.set_event_flag(&"save_enzuo_solved")
	test.expect(not ForestEnzuoSavedInteraction.should_show(2, before_boss), "The solved Enzuo interaction is hidden permanently.")
