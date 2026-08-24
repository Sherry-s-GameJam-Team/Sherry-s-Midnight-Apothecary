extends RefCounted


static func run(test: TestSupport) -> void:
	var thrower := PotionThrower.new()
	test.expect(not thrower.tutorial_hint_text.is_empty(), "Potion throwing has a player-facing tutorial message.")
	test.expect(thrower.tutorial_hint_text != thrower.tutorial_hint_id, "Potion throwing never exposes its internal tutorial key as HintUI text.")
	var tuning := PotionThrowTuning.new()
	test.expect_float_close(PotionThrower.calculate_dose_for_aim_time(0.0, tuning), 0.05, 0.001, "A tap consumes the minimum five-percent dose.")
	test.expect_float_close(PotionThrower.calculate_dose_for_aim_time(2.0, tuning), 0.25, 0.001, "Two real-time aim seconds reach the effect threshold.")
	test.expect_float_close(PotionThrower.calculate_effect_multiplier(0.05, tuning), 1.0, 0.001, "Minimum dose applies one effect stack.")
	test.expect_float_close(PotionThrower.calculate_effect_multiplier(0.25, tuning), 4.0, 0.001, "A quarter bottle reaches four-times effect.")
	test.expect_float_close(PotionThrower.calculate_effect_multiplier(0.8, tuning), 4.0, 0.001, "Dose above a quarter bottle stays capped at four-times effect.")
