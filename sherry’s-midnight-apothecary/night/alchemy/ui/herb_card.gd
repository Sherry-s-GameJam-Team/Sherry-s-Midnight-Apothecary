class_name HerbCard
extends PanelContainer

var ingredient_data: IngredientData
var available := 0
var compact_visual := false


func setup(data: IngredientData, count: int) -> void:
	ingredient_data = data
	available = maxi(count, 0)
	tooltip_text = "%s\n可用数量：%d\n色谱：%.2f–%.2f" % [
		data.display_name, available, data.spectrum_start, data.spectrum_end,
	]
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available > 0 else Control.CURSOR_FORBIDDEN
	if compact_visual:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var count_label := Label.new()
		count_label.text = "×%d" % available
		count_label.visible = available > 0
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		count_label.add_theme_color_override("font_color", Color("#eadab6"))
		count_label.add_theme_color_override("font_shadow_color", Color("#2d1d10"))
		count_label.add_theme_constant_override("shadow_offset_x", 2)
		count_label.add_theme_constant_override("shadow_offset_y", 2)
		count_label.add_theme_font_size_override("font_size", 17)
		add_child(count_label)
		modulate = Color.WHITE if available > 0 else Color(0.52, 0.52, 0.52, 0.75)
		return
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = data.icon
	var label := Label.new()
	label.text = "%s\n库存：%d" % [data.display_name, available]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(icon)
	row.add_child(label)
	add_child(row)
	modulate = Color.WHITE if available > 0 else Color(0.55, 0.55, 0.55, 0.8)


func _get_drag_data(_position: Vector2) -> Variant:
	if ingredient_data == null or available <= 0:
		return null
	var preview := Label.new()
	preview.text = ingredient_data.display_name
	preview.add_theme_color_override("font_color", Color("#3b2414"))
	set_drag_preview(preview)
	return {"kind": &"herb", "ingredient_id": ingredient_data.id}
