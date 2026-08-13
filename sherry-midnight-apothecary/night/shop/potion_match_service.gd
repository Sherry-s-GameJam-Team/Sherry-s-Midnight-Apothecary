class_name PotionMatchService
extends RefCounted

const EFFECT_MAP := {&"attack":&"circulation", &"speed":&"activation", &"lightning_meteor":&"analgesia", &"healing":&"regeneration", &"shield":&"stabilization", &"mana":&"purification", &"purify":&"purification", &"concealment":&"sedation"}

static func calculate(event: Dictionary, potion: PotionData, instance: Dictionary) -> PotionMatchResult:
	var result := PotionMatchResult.new()
	var primary := effect_for(potion.main_effect_id)
	var secondary := effect_for(StringName(str(instance.get("secondary_effect_id", ""))))
	var traits := string_names(instance.get("traits", []))
	var special_id := StringName(str(instance.get("special_potion_id", "")))
	var wanted_primary := StringName(str(event.get("primary_need", "")))
	var wanted_secondary := StringName(str(event.get("secondary_need", "")))
	if special_id != &"" and special_id == StringName(str(event.get("preferred_special_potion_id", ""))):
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
	elif secondary == wanted_secondary:
		result.secondary_match = 20
		result.tags.append(&"correct_secondary")
	elif primary == wanted_secondary:
		result.secondary_match = 10
		result.tags.append(&"secondary_as_primary")
	else:
		result.tags.append(&"missing_secondary")
	for requirement: Variant in event.get("special_requirements", []):
		var required := StringName(str(requirement))
		if traits.has(required):
			result.special_match += 10
			result.tags.append(required)
	for forbidden: Variant in event.get("forbidden_effects", []):
		var forbidden_effect := StringName(str(forbidden))
		if primary == forbidden_effect or secondary == forbidden_effect:
			result.forbidden_penalty -= 40
			result.tags.append(&"forbidden")
	for forbidden_trait: Variant in event.get("forbidden_traits", []):
		var forbidden_id := StringName(str(forbidden_trait))
		if traits.has(forbidden_id):
			result.forbidden_penalty -= 40
			result.tags.append(forbidden_id)
	var potency := float(instance.get("potency", 1.0)) * float(instance.get("quality", 1.0))
	var severity := int(event.get("severity", 1))
	if severity >= 3 and potency < 1.0:
		result.potency_match -= 15
		result.tags.append(&"underpowered")
	elif severity == 1 and potency > 1.2:
		result.potency_match -= 10
		result.tags.append(&"overpowered")
	else:
		result.potency_match += 10
		result.tags.append(&"potency_ideal")
	result.total_score = result.primary_match + result.secondary_match + result.special_match + result.potency_match + result.forbidden_penalty + result.special_potion_bonus
	if result.forbidden_penalty < 0 or result.tags.has(&"overpowered") and instance.get("was_burned", false):
		result.outcome = PotionMatchResult.Outcome.DANGEROUS
	elif result.special_potion_bonus > 0:
		result.outcome = PotionMatchResult.Outcome.SPECIAL
	elif result.total_score >= 80:
		result.outcome = PotionMatchResult.Outcome.PERFECT
	elif result.total_score >= 55:
		result.outcome = PotionMatchResult.Outcome.SATISFIED
	elif result.total_score >= 25:
		result.outcome = PotionMatchResult.Outcome.ACCEPTABLE
	else:
		result.outcome = PotionMatchResult.Outcome.FAILED
	return result

static func effect_for(effect_id: StringName) -> StringName:
	return EFFECT_MAP.get(effect_id, &"")

static func string_names(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			result.append(StringName(str(item)))
	return result
