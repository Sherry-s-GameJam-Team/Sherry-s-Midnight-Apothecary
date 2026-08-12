class_name HeatResult
extends RefCounted

var range_ratio := 0.0
var underheat_ratio := 0.0
var overheat_ratio := 0.0
var burn_ratio := 0.0
var average_deviation := 0.0
var stability_score := 0.0
var thermal_score := 0.0
var quality_multiplier := 0.65
var potency_multiplier := 0.70
var duration_multiplier := 0.65
var preserve_secondary_effect := false
var secondary_effect_multiplier := 0.0
var is_burned := false


func temperature_grade() -> StringName:
	if is_burned:
		return &"burned"
	if thermal_score >= 0.90:
		return &"perfect_control"
	if thermal_score >= 0.75:
		return &"stable_brew"
	if thermal_score >= 0.55:
		return &"qualified"
	if thermal_score >= 0.30:
		return &"unstable"
	return &"failed_extraction"
