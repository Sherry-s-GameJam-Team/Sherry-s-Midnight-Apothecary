class_name PowderInstanceData
extends RefCounted

var source_ingredient_id: StringName
var source_instance_id: StringName
var special_potion_id: StringName
var spectrum_x := 0.5
var display_color := Color.WHITE
var quality := 1.0
var amount := 1.0
var created_day := 1
var usable_for_brewing := true


func to_dict() -> Dictionary:
	return {
		"source_ingredient_id": str(source_ingredient_id),
		"source_instance_id": str(source_instance_id),
		"special_potion_id": str(special_potion_id),
		"spectrum_x": clampf(spectrum_x, 0.0, 1.0),
		"display_color": display_color.to_html(true),
		"quality": clampf(quality, 0.1, 1.5),
		"amount": maxf(amount, 0.0),
		"created_day": maxi(created_day, 1),
		"usable_for_brewing": usable_for_brewing,
	}


static func from_dict(data: Dictionary) -> PowderInstanceData:
	var result := PowderInstanceData.new()
	result.source_ingredient_id = StringName(str(data.get("source_ingredient_id", "")))
	result.source_instance_id = StringName(str(data.get("source_instance_id", "")))
	result.special_potion_id = StringName(str(data.get("special_potion_id", "")))
	result.spectrum_x = clampf(float(data.get("spectrum_x", 0.5)), 0.0, 1.0)
	result.display_color = Color.from_string(str(data.get("display_color", "ffffffff")), Color.WHITE)
	result.quality = clampf(float(data.get("quality", 1.0)), 0.1, 1.5)
	result.amount = maxf(float(data.get("amount", 1.0)), 0.0)
	result.created_day = maxi(int(data.get("created_day", 1)), 1)
	result.usable_for_brewing = bool(data.get("usable_for_brewing", true))
	return result


func duplicate_instance() -> PowderInstanceData:
	return from_dict(to_dict())
