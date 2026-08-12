class_name PowderItemView
extends PanelContainer

var powder: PowderInstanceData
var flour_texture: Texture2D
var paper_texture: Texture2D


func setup(value: PowderInstanceData, texture: Texture2D, backing_texture: Texture2D = null) -> void:
	powder = value
	flour_texture = texture
	paper_texture = backing_texture
	tooltip_text = "%s\n色值 %.3f\n品质 %.2f\n份量 %.2f" % [
		powder.source_ingredient_id, powder.spectrum_x, powder.quality, powder.amount,
	]
	if paper_texture != null:
		var paper := TextureRect.new()
		paper.name = "Paper"
		paper.texture = paper_texture
		paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(paper)
	var preview := TextureRect.new()
	preview.name = "Powder"
	preview.texture = flour_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = powder.display_color
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "%s\n%.2f" % [powder.source_ingredient_id, powder.amount]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color("#f3dfb5"))
	label.add_theme_color_override("font_shadow_color", Color("#28180d"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(preview)
	add_child(label)


func _get_drag_data(_position: Vector2) -> Variant:
	if powder == null or not powder.usable_for_brewing:
		return null
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(90, 55)
	preview.texture = flour_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = powder.display_color
	set_drag_preview(preview)
	return {"kind": &"powder", "instance_id": powder.source_instance_id}
