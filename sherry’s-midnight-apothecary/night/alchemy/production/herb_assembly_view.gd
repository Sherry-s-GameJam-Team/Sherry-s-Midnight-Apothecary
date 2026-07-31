class_name HerbAssemblyView
extends Control


func setup(ingredient: IngredientData, pieces: Array[ProductionRuntimeTypes.HerbPieceRuntime]) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var canvas_size := ingredient.reference_canvas_size if ingredient != null else Vector2i.ZERO
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece == null or piece.data == null or piece.data.texture == null:
			continue
		var source := piece.data.source_rect
		if source.size.x <= 0 or source.size.y <= 0:
			continue
		var sprite := TextureRect.new()
		sprite.name = str(piece.data.id)
		sprite.anchor_left = float(source.position.x) / canvas_size.x
		sprite.anchor_top = float(source.position.y) / canvas_size.y
		sprite.anchor_right = float(source.end.x) / canvas_size.x
		sprite.anchor_bottom = float(source.end.y) / canvas_size.y
		sprite.texture = piece.data.texture
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_SCALE
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.z_index = piece.data.z_order
		add_child(sprite)


func has_visual_pieces() -> bool:
	return get_child_count() > 0
