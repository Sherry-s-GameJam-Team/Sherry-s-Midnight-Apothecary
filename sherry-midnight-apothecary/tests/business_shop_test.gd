extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://night/shop/shop_runtime.tscn") as PackedScene
	test.expect(scene != null, "The shop runtime loads.")
	if scene == null:
		return
	for day in range(8):
		test.expect_equal(CustomerEventCatalog.customer_cap_for_day(day), mini(day + 2, 8), "Customer capacity grows on day %d." % day)
	var voiced_cases := CustomerEventCatalog.eligible_for_day(5, {}, {})
	var unique_requests: Dictionary = {}
	var unique_perfect_lines: Dictionary = {}
	for voiced_case: Dictionary in voiced_cases:
		var feedback_lines: Array = voiced_case.get("feedback_lines", [])
		test.expect(str(voiced_case.get("request", "")).contains("诊疗需求："), "Every voiced request keeps an explicit mechanical requirement line.")
		test.expect_equal(feedback_lines.size(), 6, "Every NPC supplies all six treatment outcome lines.")
		test.expect(not str(voiced_case.get("refusal_line", "")).is_empty(), "Every NPC has a personalized refusal line.")
		test.expect(not str(voiced_case.get("permanent_departure_line", "")).is_empty(), "Every NPC has a personalized permanent-departure line.")
		unique_requests[str(voiced_case.get("request", ""))] = true
		unique_perfect_lines[str(feedback_lines[0])] = true
	test.expect_equal(unique_requests.size(), 8, "All eight NPCs have distinct case dialogue.")
	test.expect_equal(unique_perfect_lines.size(), 8, "All eight NPCs react to perfect treatment in their own voice.")
	var worsened_milo: Dictionary = CustomerEventCatalog.eligible_for_day(3, {}, {"young_villager":{"visit_count":1, "case_stage":1, "case_branch":"worsened", "next_visit_day":0}}).filter(func(item: Dictionary) -> bool: return item.npc_id == &"young_villager").front()
	test.expect(str(worsened_milo.request).contains("更难受"), "A worsened follow-up uses the NPC-specific deterioration line.")

	var shop := scene.instantiate() as ShopRuntime
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(shop)
	var player := PlayerData.new()
	var result := NightResult.new()
	shop.setup(player, result, 0)
	test.expect_equal(shop._customer_queue.size(), 2, "Tutorial night starts with two customers.")
	test.expect_equal(shop.day, 0, "Tutorial night remains day zero.")

	var rejected := shop.current_customer()
	var rejected_id := str(rejected.npc_id)
	shop._on_reject_pressed()
	var rejected_state: Dictionary = player.customer_states.get(rejected_id, {})
	test.expect_equal(int(rejected_state.get("next_visit_day", -1)), 2, "A refusal delays the same diagnosis by two days.")
	test.expect_equal(int(rejected_state.get("case_stage", -1)), 0, "A refusal does not advance the diagnosis.")
	test.expect_equal(result.reputation_delta, -2, "First refusal keeps the exponential reputation penalty.")

	shop.setup(player, NightResult.new(), 1)
	test.expect(not shop._customer_queue.any(func(c: Dictionary) -> bool: return str(c.npc_id) == rejected_id), "A rejected NPC cannot return before next_visit_day.")
	test.expect(shop._customer_queue.size() <= 3, "Day one respects its three-customer cap.")

	var orange := load("res://shared/definitions/data/potions/orange_potion.tres") as PotionData
	var green := load("res://shared/definitions/data/potions/green_potion.tres") as PotionData
	var blue := load("res://shared/definitions/data/potions/blue_potion.tres") as PotionData
	var purple := load("res://shared/definitions/data/potions/purple_potion.tres") as PotionData
	var purification := load("res://shared/definitions/data/potions/purification_potion.tres") as PotionData

	var single_event := {"primary_need":&"activation", "secondary_need":&"", "severity":1, "forbidden_effects":[]}
	var single_match := PotionMatchService.calculate(single_event, orange, {"quality":1.0, "potency":1.0})
	test.expect_equal(single_match.outcome, PotionMatchResult.Outcome.PERFECT, "An exact introductory single effect is perfect.")
	test.expect_float_close(single_match.normalized_score, 1.0, 0.001, "Single-effect matching normalizes against its attainable score.")

	var compound_event := {"primary_need":&"activation", "secondary_need":&"regeneration", "severity":2, "forbidden_effects":[]}
	var compound := PotionMatchService.calculate(compound_event, orange, {"secondary_effect_id":"healing", "secondary_effect_multiplier":1.0, "quality":1.0, "potency":1.0})
	test.expect_equal(compound.outcome, PotionMatchResult.Outcome.PERFECT, "The directed main/secondary pair can match perfectly.")
	var partial := PotionMatchService.calculate(compound_event, orange, {"secondary_effect_id":"healing", "secondary_effect_multiplier":0.5, "quality":1.0, "potency":1.0})
	test.expect_equal(partial.outcome, PotionMatchResult.Outcome.SATISFIED, "A half-strength secondary effect earns partial credit.")
	var reversed := PotionMatchService.calculate(compound_event, green, {"secondary_effect_id":"speed", "secondary_effect_multiplier":1.0, "quality":1.0, "potency":1.0})
	test.expect(reversed.outcome != PotionMatchResult.Outcome.SATISFIED and reversed.outcome != PotionMatchResult.Outcome.PERFECT, "Reversing an ordered pair cannot satisfy the requested primary effect.")

	var forbidden_event := {"primary_need":&"purification", "secondary_need":&"", "severity":1, "forbidden_effects":[&"sedation"]}
	var dangerous := PotionMatchService.calculate(forbidden_event, purple, {"quality":1.0, "potency":1.0})
	test.expect_equal(dangerous.outcome, PotionMatchResult.Outcome.DANGEROUS, "A forbidden color effect is dangerous.")
	var burned := PotionMatchService.calculate(single_event, orange, {"quality":1.0, "potency":1.0, "was_burned":true})
	test.expect_equal(burned.outcome, PotionMatchResult.Outcome.DANGEROUS, "Any burned brew is dangerous.")

	var special_event := {"primary_need":&"purification", "secondary_need":&"", "severity":3, "forbidden_effects":[], "preferred_special_potion_id":&"purification_potion"}
	var special := PotionMatchService.calculate(special_event, purification, {"special_potion_id":"purification_potion", "quality":1.0, "potency":1.0})
	test.expect_equal(special.outcome, PotionMatchResult.Outcome.SPECIAL, "High-purity blue resolves its explicit special request.")

	var follow_customer: Dictionary = CustomerEventCatalog.eligible_for_day(0, {}, {}).front()
	var perfect_feedback := CustomerFeedbackResolver.resolve(follow_customer, single_match)
	shop.day = 0
	shop.selected_potion_id = orange.id
	shop._record_customer_result(follow_customer, {"quality":1.0, "potency":1.0}, single_match, perfect_feedback)
	var follow_state: Dictionary = player.customer_states.get(str(follow_customer.npc_id), {})
	test.expect_equal(int(follow_state.get("case_stage", -1)), 1, "Perfect treatment advances the case stage.")
	test.expect_equal(int(follow_state.get("next_visit_day", -1)), 2, "Perfect treatment schedules a two-day follow-up.")

	var failed := PotionMatchService.calculate(single_event, blue, {"quality":1.0, "potency":1.0})
	var failed_feedback := CustomerFeedbackResolver.resolve(follow_customer, failed)
	shop._record_customer_result(follow_customer, {"quality":1.0, "potency":1.0}, failed, failed_feedback)
	follow_state = player.customer_states.get(str(follow_customer.npc_id), {})
	test.expect_equal(str(follow_state.get("case_branch", "")), "worsened", "Failed treatment records a worsened branch.")
	test.expect_equal(int(follow_state.get("next_visit_day", -1)), 1, "Failed treatment requests re-examination after one day.")

	shop.free()
