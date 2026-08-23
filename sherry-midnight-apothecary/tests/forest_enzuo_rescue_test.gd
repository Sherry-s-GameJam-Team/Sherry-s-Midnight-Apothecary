extends RefCounted


static func run(test: TestSupport) -> void:
	test.expect(ForestDayOneEnzuoIntro.should_trigger_post_boss(1, true, true, false), "Enzuo is released only after the day-one intro and forest Boss completion.")
	test.expect(not ForestDayOneEnzuoIntro.should_trigger_post_boss(1, true, false, false), "Enzuo remains suspended until the Boss is purified.")
	test.expect(not ForestDayOneEnzuoIntro.should_trigger_post_boss(1, false, true, false), "The post-Boss sequence requires the initial meeting.")
	test.expect(not ForestDayOneEnzuoIntro.should_trigger_post_boss(1, true, true, true), "A completed rescue cannot replay.")
	test.expect(not ForestDayOneEnzuoIntro.should_trigger_post_boss(2, true, true, false), "The Enzuo resolution belongs to day one.")
