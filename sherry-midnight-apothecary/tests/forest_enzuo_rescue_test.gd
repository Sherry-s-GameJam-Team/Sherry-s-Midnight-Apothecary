extends RefCounted


static func run(test: TestSupport) -> void:
	test.expect(ForestEnzuoRescueController.should_offer(1, true, false), "Enzuo rescue is offered after the first-day introduction.")
	test.expect(not ForestEnzuoRescueController.should_offer(0, true, false), "Enzuo rescue is hidden outside day one.")
	test.expect(not ForestEnzuoRescueController.should_offer(1, false, false), "Enzuo rescue waits for its first-meeting event.")
	test.expect(not ForestEnzuoRescueController.should_offer(1, true, true), "Solved Enzuo rescue is hidden.")
	test.expect_equal(ForestEnzuoRescueController.round_vine_count(0), 2, "Round one contains two side vines.")
	test.expect_equal(ForestEnzuoRescueController.round_vine_count(1), 3, "Round two contains three side vines.")
	test.expect_equal(ForestEnzuoRescueController.round_vine_count(2), 2, "Round three contains two side vines.")
	test.expect(ForestEnzuoRescueController.segment_hits_segment_width(Vector2(0, 0), Vector2(100, 0), Vector2(50, -30), Vector2(50, 30), 1.0), "A continuous flight segment cuts a crossed side vine.")
	test.expect(not ForestEnzuoRescueController.segment_hits_segment_width(Vector2(0, 0), Vector2(100, 0), Vector2(50, 30), Vector2(50, 60), 8.0), "A safe flight segment does not cut a distant vine.")
