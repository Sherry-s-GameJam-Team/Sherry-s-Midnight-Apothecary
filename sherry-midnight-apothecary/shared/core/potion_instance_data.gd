class_name PotionInstanceData
extends RefCounted

var potion_id: StringName
var primary_effect_id: StringName
var instance_uid := ""
var remaining_dose := 1.0
var mixed_x := 0.0
var secondary_effect_id: StringName
var secondary_effect_multiplier := 1.0
var quality := 0.1
var potency := 1.0
var duration := 1.0
var price_multiplier := 1.0
var thermal_score := 1.0
var temperature_grade: StringName = &"stable_brew"
var was_burned := false
var created_day := 1
var bottle_style_id: StringName = &"health"
var custom_name := ""
var actual_color: Array = []
var traits: Array[StringName] = []
var special_potion_id: StringName = &""


func to_dict() -> Dictionary:
	return {
		"potion_id": str(potion_id),
		"primary_effect_id": str(primary_effect_id),
		"instance_uid": instance_uid,
		"remaining_dose": clampf(remaining_dose, 0.0, 1.0),
		"mixed_x": mixed_x,
		"secondary_effect_id": str(secondary_effect_id),
		"secondary_effect_multiplier": clampf(secondary_effect_multiplier, 0.0, 1.0),
		"quality": quality,
		"potency": clampf(potency, 0.5, 1.25),
		"duration": clampf(duration, 0.4, 1.3),
		"price_multiplier": maxf(price_multiplier, 0.1),
		"thermal_score": clampf(thermal_score, 0.0, 1.0),
		"temperature_grade": str(temperature_grade),
		"was_burned": was_burned,
		"created_day": created_day,
		"bottle_style_id": str(bottle_style_id),
		"custom_name": custom_name,
		"actual_color": actual_color.duplicate(),
		"traits": _serialize_traits(),
		"special_potion_id": str(special_potion_id),
	}


static func from_dict(data: Dictionary) -> PotionInstanceData:
	var result := PotionInstanceData.new()
	result.potion_id = StringName(str(data.get("potion_id", "")))
	result.primary_effect_id = StringName(str(data.get("primary_effect_id", "")))
	result.instance_uid = str(data.get("instance_uid", ""))
	result.remaining_dose = clampf(float(data.get("remaining_dose", 1.0)), 0.0, 1.0)
	result.mixed_x = clampf(float(data.get("mixed_x", 0.0)), 0.0, 1.0)
	result.secondary_effect_id = StringName(str(data.get("secondary_effect_id", "")))
	result.secondary_effect_multiplier = clampf(float(data.get("secondary_effect_multiplier", 1.0)), 0.0, 1.0)
	result.quality = clampf(float(data.get("quality", 0.1)), 0.1, 1.5)
	result.potency = clampf(float(data.get("potency", 1.0)), 0.5, 1.25)
	result.duration = clampf(float(data.get("duration", 1.0)), 0.4, 1.3)
	result.price_multiplier = maxf(float(data.get("price_multiplier", 1.0)), 0.1)
	result.thermal_score = clampf(float(data.get("thermal_score", 1.0)), 0.0, 1.0)
	result.temperature_grade = StringName(str(data.get("temperature_grade", "stable_brew")))
	result.was_burned = bool(data.get("was_burned", false))
	result.created_day = maxi(int(data.get("created_day", 1)), 1)
	result.bottle_style_id = StringName(str(data.get("bottle_style_id", "health")))
	result.custom_name = str(data.get("custom_name", "")).left(12)
	result.actual_color = (data.get("actual_color", []) as Array).duplicate()
	if data.get("traits", []) is Array:
		for trait_id in data.get("traits", []):
			result.traits.append(StringName(str(trait_id)))
	result.special_potion_id = StringName(str(data.get("special_potion_id", "")))
	return result


func _serialize_traits() -> Array[String]:
	var result: Array[String] = []
	for trait_id in traits:
		result.append(str(trait_id))
	return result
