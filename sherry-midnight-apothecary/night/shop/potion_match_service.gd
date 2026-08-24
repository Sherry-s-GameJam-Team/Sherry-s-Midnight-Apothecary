class_name PotionMatchService
extends RefCounted

static func calculate(event: Dictionary, potion: PotionData, instance: Dictionary) -> PotionMatchResult:
	var result := PotionMatchResult.new()
	if potion == null:
		return result
	var primary := effect_for(potion.main_effect_id)
	var secondary := effect_for(StringName(str(instance.get("secondary_effect_id", ""))))
	var special_id := StringName(str(instance.get("special_potion_id", "")))
	var wanted_primary := StringName(str(event.get("primary_need", "")))
	var wanted_secondary := StringName(str(event.get("secondary_need", "")))
	var wanted_special := StringName(str(event.get("preferred_special_potion_id", "")))
	var special_matches := wanted_special != &"" and special_id == wanted_special
	result.maximum_score = 50 + 15 + (25 if wanted_secondary != &"" else 0) + (30 if wanted_special != &"" else 0)
	if special_matches:
		result.special_potion_bonus = 30
		result.tags.append(&"special_potion")
		result.tags.append(StringName("special_id_%s" % special_id))
	if primary == wanted_primary:
		result.primary_match = 50
		result.tags.append(&"correct_primary")
	elif secondary == wanted_primary:
		result.primary_match = 20
		result.tags.append(&"primary_as_secondary")
	else:
		result.tags.append(&"wrong_primary")
	if wanted_secondary == &"":
		pass
	elif secondary == wanted_secondary or secondary == &"" and primary == wanted_secondary:
		var secondary_multiplier := 1.0 if secondary == &"" else clampf(float(instance.get("secondary_effect_multiplier", 1.0)), 0.0, 1.0)
		result.secondary_match = roundi(25.0 * secondary_multiplier)
		result.tags.append(&"correct_secondary")
	elif primary == wanted_secondary:
		result.secondary_match = 10
		result.tags.append(&"secondary_as_primary")
	else:
		result.tags.append(&"missing_secondary")
	for forbidden: Variant in event.get("forbidden_effects", []):
		var forbidden_effect := StringName(str(forbidden))
		if primary == forbidden_effect or secondary == forbidden_effect:
			result.forbidden_penalty -= 40
			result.tags.append(&"forbidden")
	var potency := float(instance.get("potency", 1.0)) * float(instance.get("quality", 1.0))
	var severity := int(event.get("severity", 1))
	var minimum_potency := 1.0 if severity >= 3 else 0.8 if severity == 2 else 0.5
	if potency < minimum_potency:
		result.potency_match = 5
		result.tags.append(&"underpowered")
	elif severity == 1 and potency > 1.2:
		result.potency_match = 0
		result.tags.append(&"overpowered")
	else:
		result.potency_match = 15
		result.tags.append(&"potency_ideal")
	result.total_score = result.primary_match + result.secondary_match + result.special_match + result.potency_match + result.forbidden_penalty + result.special_potion_bonus
	result.normalized_score = clampf(float(result.total_score) / maxf(float(result.maximum_score), 1.0), 0.0, 1.0)
	if result.forbidden_penalty < 0 or bool(instance.get("was_burned", false)):
		result.outcome = PotionMatchResult.Outcome.DANGEROUS
	elif special_matches and primary == wanted_primary:
		result.outcome = PotionMatchResult.Outcome.SPECIAL
	elif primary != wanted_primary:
		result.outcome = PotionMatchResult.Outcome.ACCEPTABLE if result.normalized_score >= 0.45 else PotionMatchResult.Outcome.FAILED
	elif result.normalized_score >= 0.90:
		result.outcome = PotionMatchResult.Outcome.PERFECT
	elif result.normalized_score >= 0.70:
		result.outcome = PotionMatchResult.Outcome.SATISFIED
	elif result.normalized_score >= 0.45:
		result.outcome = PotionMatchResult.Outcome.ACCEPTABLE
	else:
		result.outcome = PotionMatchResult.Outcome.FAILED
	return result

static func effect_for(effect_id: StringName) -> StringName:
	return PotionEffectMatrix.canonical_effect_id(effect_id)

static func string_names(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			result.append(StringName(str(item)))
	return result
