class_name PotionInstanceData
extends RefCounted

var potion_id: StringName
var mixed_x := 0.0
var secondary_effect_id: StringName
var quality := 0.1
var created_day := 1


func to_dict() -> Dictionary:
	return {
		"potion_id": str(potion_id),
		"mixed_x": mixed_x,
		"secondary_effect_id": str(secondary_effect_id),
		"quality": quality,
		"created_day": created_day,
	}


static func from_dict(data: Dictionary) -> PotionInstanceData:
	var result := PotionInstanceData.new()
	result.potion_id = StringName(str(data.get("potion_id", "")))
	result.mixed_x = clampf(float(data.get("mixed_x", 0.0)), 0.0, 1.0)
	result.secondary_effect_id = StringName(str(data.get("secondary_effect_id", "")))
	result.quality = clampf(float(data.get("quality", 0.1)), 0.1, 1.5)
	result.created_day = maxi(int(data.get("created_day", 1)), 1)
	return result
