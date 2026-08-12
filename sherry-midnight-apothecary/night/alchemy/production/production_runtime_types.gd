class_name ProductionRuntimeTypes
extends RefCounted


class HerbPieceRuntime:
	extends RefCounted

	enum State {
		ATTACHED,
		SEPARATED,
		WASTE,
		GRIND,
		GROUND,
		PACKED,
		SHELVED,
		DISCARDED,
	}

	var data: HerbPieceData
	var source_ingredient: IngredientData
	var source_instance_id: StringName
	var state := State.ATTACHED
	var quality := 1.0
	var concentration := 1.0
	var layer_yield_multiplier := 1.0
	var scatter_rotation := 0.0
	var workspace_position := Vector2.ZERO
	var has_workspace_position := false
	var stack_z := 0

	func weight() -> float:
		return maxf(effective_yield() * concentration, 0.0)

	func effective_yield() -> float:
		if data == null:
			return 0.0
		return maxf(data.effective_yield() * layer_yield_multiplier, 0.0)


static func create_piece_set(
	ingredient: IngredientData,
	source_instance_id: StringName = &"",
	initial_state: int = HerbPieceRuntime.State.ATTACHED
) -> Array[HerbPieceRuntime]:
	var result: Array[HerbPieceRuntime] = []
	if ingredient == null or ingredient.spectrum_start >= ingredient.spectrum_end:
		return result
	if not ingredient.production_layers.is_empty():
		var piece_index := 0
		for layer: HerbColorLayerData in ingredient.production_layers:
			if layer == null:
				continue
			for piece_data: HerbPieceData in layer.pieces:
				if piece_data == null:
					continue
				var runtime := HerbPieceRuntime.new()
				runtime.data = piece_data
				runtime.source_ingredient = ingredient
				runtime.source_instance_id = source_instance_id
				runtime.state = initial_state
				runtime.quality = clampf(ingredient.base_quality * piece_data.quality_multiplier, 0.1, 1.5)
				runtime.concentration = clampf(ingredient.base_concentration * piece_data.concentration_multiplier, 0.05, 2.0)
				runtime.layer_yield_multiplier = maxf(layer.layer_yield_multiplier, 0.0)
				runtime.scatter_rotation = float((piece_index % 5) - 2) * 1.8
				result.append(runtime)
				piece_index += 1
		return result
	var center := (ingredient.spectrum_start + ingredient.spectrum_end) * 0.5
	var width := ingredient.spectrum_end - ingredient.spectrum_start
	var templates: Array[Dictionary] = [
		{"id": &"leaf", "name": "叶片", "ratio": 0.45, "offset": -0.22},
		{"id": &"stem", "name": "茎秆", "ratio": 0.30, "offset": 0.0},
		{"id": &"blossom", "name": "花穗", "ratio": 0.25, "offset": 0.24},
	]
	for template: Dictionary in templates:
		var piece_data := HerbPieceData.new()
		piece_data.id = StringName("%s_%s" % [ingredient.id, template["id"]])
		piece_data.display_name = "%s·%s" % [ingredient.display_name, template["name"]]
		piece_data.area_ratio = float(template["ratio"])
		piece_data.spectrum_x = clampf(center + width * float(template["offset"]), ingredient.spectrum_start, ingredient.spectrum_end)
		piece_data.display_color = spectrum_color(piece_data.spectrum_x)
		var runtime := HerbPieceRuntime.new()
		runtime.data = piece_data
		runtime.source_ingredient = ingredient
		runtime.source_instance_id = source_instance_id
		runtime.state = initial_state
		runtime.quality = clampf(ingredient.base_quality, 0.1, 1.5)
		runtime.concentration = clampf(ingredient.base_concentration, 0.05, 2.0)
		result.append(runtime)
	return result


static func spectrum_color(value: float) -> Color:
	var colors: Array[Color] = [
		Color("#c6493f"), Color("#dc873b"), Color("#e2c84d"), Color("#72a158"),
		Color("#55aca9"), Color("#5277bd"), Color("#8557a6"),
	]
	var scaled := clampf(value, 0.0, 1.0) * float(colors.size() - 1)
	var left := mini(floori(scaled), colors.size() - 1)
	var right := mini(left + 1, colors.size() - 1)
	return colors[left].lerp(colors[right], scaled - float(left))
