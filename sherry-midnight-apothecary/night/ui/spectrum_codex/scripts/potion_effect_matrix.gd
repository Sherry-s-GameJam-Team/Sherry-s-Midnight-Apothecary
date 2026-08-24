class_name PotionEffectMatrix
extends Resource

const EFFECT_IDS: Array[StringName] = [
	&"circulation", &"activation", &"analgesia", &"regeneration",
	&"stabilization", &"purification", &"sedation",
]
const LEGACY_EFFECT_MAP := {
	&"attack": &"circulation", &"speed": &"activation",
	&"lightning_meteor": &"analgesia", &"healing": &"regeneration",
	&"shield": &"stabilization", &"mana": &"purification",
	&"purify": &"purification", &"concealment": &"sedation",
}

@export var combinations: Array[PotionEffectCombination] = []


static func canonical_effect_id(effect_id: StringName) -> StringName:
	return LEGACY_EFFECT_MAP.get(effect_id, effect_id if EFFECT_IDS.has(effect_id) else &"")


func get_combination(primary_effect_id: StringName, secondary_effect_id: StringName = &"") -> PotionEffectCombination:
	var resolved_secondary := primary_effect_id if secondary_effect_id == &"" else secondary_effect_id
	for combination in combinations:
		if combination != null and combination.primary_effect_id == primary_effect_id and combination.secondary_effect_id == resolved_secondary:
			return combination
	return null


func get_combination_at(row: int, col: int) -> PotionEffectCombination:
	for combination in combinations:
		if combination != null and combination.matrix_row == row and combination.matrix_col == col:
			return combination
	return null


func coordinate_for(primary_effect_id: StringName, secondary_effect_id: StringName = &"") -> Vector2i:
	var combination := get_combination(primary_effect_id, secondary_effect_id)
	return Vector2i(combination.matrix_row, combination.matrix_col) if combination != null else Vector2i(-1, -1)


func is_complete() -> bool:
	if combinations.size() != 49:
		return false
	for row in range(7):
		for col in range(7):
			if get_combination_at(row, col) == null:
				return false
	return true
