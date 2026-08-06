class_name PotionColorResolver
extends RefCounted


static func resolve(potion: PotionData, instance: Dictionary) -> Color:
	if potion == null:
		return Color.WHITE
	var explicit := _explicit_color(instance)
	var color := explicit if explicit.a > 0.0 else potion.display_color
	if explicit.a <= 0.0:
		var mixed_x := _mix_position(instance)
		var offset := clampf(mixed_x - potion.spectrum_center_x, -0.12, 0.12)
		color.h = fposmod(color.h + offset * 0.22, 1.0)
	var quality := clampf(float(instance.get("quality", 1.0)), 0.1, 1.5)
	var potency := clampf(float(instance.get("potency", 1.0)), 0.5, 1.25)
	color.v = clampf(color.v * lerpf(0.84, 1.12, quality / 1.5), 0.15, 1.0)
	color.s = clampf(color.s * lerpf(0.86, 1.12, potency / 1.25), 0.1, 1.0)
	color.a = 1.0
	return color


static func _mix_position(instance: Dictionary) -> float:
	for key in ["mixed_x", "mix_position", "spectrum_x"]:
		if instance.has(key):
			var value: Variant = instance[key]
			if value is Vector2:
				return clampf((value as Vector2).x, 0.0, 1.0)
			if value is Vector3:
				return clampf((value as Vector3).x, 0.0, 1.0)
			if value is float or value is int:
				return clampf(float(value), 0.0, 1.0)
	return 0.5


static func _explicit_color(instance: Dictionary) -> Color:
	for key in ["actual_color", "mixed_color", "liquid_color"]:
		if not instance.has(key):
			continue
		var value: Variant = instance[key]
		if value is Color:
			return value
		if value is String and Color.html_is_valid(str(value)):
			return Color.from_string(str(value), Color.TRANSPARENT)
		if value is Array and value.size() >= 3:
			return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) if value.size() > 3 else 1.0)
	return Color.TRANSPARENT

