class_name HerbCard
extends PanelContainer

var ingredient_data: IngredientData
var available := 0
var compact_visual := false
var compact_icon: Texture2D


func setup(data: IngredientData, count: int) -> void:
	ingredient_data = data
	available = maxi(count, 0)
	if compact_visual:
		_build_compact_visual(data)
	else:
		_build_regular_visual(data)
	update_available(available)


func update_available(count: int) -> void:
	available = maxi(count, 0)
	_build_tooltip()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available > 0 else Control.CURSOR_FORBIDDEN
	var count_label := get_node_or_null("Content/CountLabel") as Label
	if count_label != null:
		count_label.text = str(available)
	var inventory_label := get_node_or_null("InventoryLabel") as Label
	if inventory_label != null and ingredient_data != null:
		inventory_label.text = "%s\n库存：%d" % [ingredient_data.display_name, available]
	modulate = (
		Color.WHITE if available > 0
		else Color(0.52, 0.52, 0.52, 0.75) if compact_visual
		else Color(0.55, 0.55, 0.55, 0.8)
	)


func _build_tooltip() -> void:
	if ingredient_data == null:
		tooltip_text = ""
		return
	var tooltip_lines: Array[String] = [ingredient_data.display_name]
	if not ingredient_data.english_name.is_empty():
		tooltip_lines.append(ingredient_data.english_name)
	if not ingredient_data.description.is_empty():
		tooltip_lines.append(ingredient_data.description)
	tooltip_lines.append("数量：%d" % available)
	tooltip_lines.append("色谱：%.2f–%.2f" % [ingredient_data.spectrum_start, ingredient_data.spectrum_end])
	tooltip_lines.append("可拖拽到加工台" if available > 0 else "库存为 0，当前不可用")
	tooltip_text = "\n".join(tooltip_lines)


func _build_compact_visual(data: IngredientData) -> void:
	clip_contents = true
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# PanelContainer lays out every direct Control child to its full content
	# rect. Keep the artwork under a plain Control so anchors stay local.
	var content := Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var icon := TextureRect.new()
	icon.name = "HerbIcon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6.0
	icon.offset_top = 13.0
	icon.offset_right = -6.0
	icon.offset_bottom = -8.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = compact_icon if compact_icon != null else data.icon
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.z_index = 1
	name_label.anchor_right = 1.0
	name_label.anchor_bottom = 0.22
	name_label.text = data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_color_override("font_color", Color("#3b2816"))
	name_label.add_theme_color_override("font_outline_color", Color("#eadab6"))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_font_size_override("font_size", 9)
	content.add_child(name_label)
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.z_index = 1
	count_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.offset_left = -23.0
	count_label.offset_top = -22.0
	count_label.offset_right = 1.0
	count_label.offset_bottom = 2.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_color_override("font_color", Color("#eadab6"))
	count_label.add_theme_color_override("font_shadow_color", Color("#2d1d10"))
	count_label.add_theme_constant_override("shadow_offset_x", 1)
	count_label.add_theme_constant_override("shadow_offset_y", 1)
	count_label.add_theme_font_size_override("font_size", 12)
	content.add_child(count_label)


func _build_regular_visual(data: IngredientData) -> void:
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = data.icon
	var label := Label.new()
	label.name = "InventoryLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(icon)
	row.add_child(label)
	add_child(row)


func _get_drag_data(_position: Vector2) -> Variant:
	if ingredient_data == null or available <= 0:
		return null
	var preview := Label.new()
	preview.text = ingredient_data.display_name
	preview.add_theme_color_override("font_color", Color("#3b2414"))
	if get_viewport() != null and get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.free()
	return {"kind": &"herb", "ingredient_id": ingredient_data.id}
