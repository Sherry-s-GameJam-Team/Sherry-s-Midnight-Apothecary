extends RefCounted


static func run(test: TestSupport) -> void:
	var thrower := PotionThrower.new()
	test.expect(not thrower.tutorial_hint_text.is_empty(), "Potion throwing has a player-facing tutorial message.")
	test.expect(thrower.tutorial_hint_text != thrower.tutorial_hint_id, "Potion throwing never exposes its internal tutorial key as HintUI text.")
