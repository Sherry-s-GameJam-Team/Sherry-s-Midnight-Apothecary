class_name PotionSvgRenderer
extends RefCounted

const TEMPLATE_PATH := "res://shared/potions/visuals/potion_bottle_template.svg"
static var _cache: Dictionary = {}
static var _template_text := ""


static func get_bottle_texture(color: Color, size := 96, fill_ratio := 1.0, glow_strength := 1.0) -> Texture2D:
	var safe_fill := clampf(fill_ratio, 0.0, 1.0)
	var key := "%s|%d|%d|%d" % [color.to_html(false), size, roundi(safe_fill * 100.0), roundi(glow_strength * 100.0)]
	if _cache.has(key):
		return _cache[key]
	if _template_text.is_empty():
		var file := FileAccess.open(TEMPLATE_PATH, FileAccess.READ)
		if file == null:
			return null
		_template_text = file.get_as_text()
	var glow_color := color.lightened(clampf(0.2 + glow_strength * 0.15, 0.0, 0.55))
	var fill_y := lerpf(124.0, 52.0, safe_fill)
	var svg := _template_text.replace("{{LIQUID_COLOR}}", "#" + color.to_html(false))
	svg = svg.replace("{{GLOW_COLOR}}", "#" + glow_color.to_html(false))
	svg = svg.replace("{{FILL_HEIGHT}}", "%.2f" % fill_y)
	var image := Image.new()
	var error := image.load_svg_from_string(svg, float(size) / 96.0)
	if error != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func clear_cache() -> void:
	_cache.clear()
