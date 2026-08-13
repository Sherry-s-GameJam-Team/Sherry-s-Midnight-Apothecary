class_name PotionMatchResult
extends RefCounted

enum Outcome { PERFECT, SATISFIED, ACCEPTABLE, FAILED, DANGEROUS, SPECIAL }

var primary_match := 0
var secondary_match := 0
var special_match := 0
var potency_match := 0
var forbidden_penalty := 0
var special_potion_bonus := 0
var total_score := 0
var outcome := Outcome.FAILED
var tags: Array[StringName] = []


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


func outcome_id() -> StringName:
	return ["PERFECT", "SATISFIED", "ACCEPTABLE", "FAILED", "DANGEROUS", "SPECIAL"][outcome]
