class_name ProcessedIngredient
extends RefCounted

var source_ingredient_id: StringName
var source_data: IngredientData
var selected_start := 0.0
var selected_end := 1.0
var spectrum_x := 0.5
var quality := 1.0
var concentration := 1.0
var extraction_ratio := 1.0
var applied_tools: Array[StringName] = []


static func from_ingredient(data: IngredientData) -> ProcessedIngredient:
	if data == null or data.spectrum_start >= data.spectrum_end:
		return null
	var result := ProcessedIngredient.new()
	result.source_ingredient_id = data.id
	result.source_data = data
	result.selected_start = data.spectrum_start
	result.selected_end = data.spectrum_end
	result.quality = clampf(data.base_quality, 0.1, 1.5)
	result.concentration = clampf(data.base_concentration, 0.05, 2.0)
	result.recalculate()
	return result


func set_selection(start_x: float, end_x: float, minimum_width := 0.01) -> bool:
	if source_data == null or source_data.spectrum_start >= source_data.spectrum_end:
		return false
	var clamped_start := clampf(start_x, source_data.spectrum_start, source_data.spectrum_end)
	var clamped_end := clampf(end_x, source_data.spectrum_start, source_data.spectrum_end)
	if clamped_end - clamped_start < minimum_width:
		return false
	selected_start = clamped_start
	selected_end = clamped_end
	recalculate()
	return true


func recalculate() -> void:
	if source_data == null:
		spectrum_x = 0.5
		extraction_ratio = 0.0
		return
	var source_width := source_data.spectrum_end - source_data.spectrum_start
	if source_width <= 0.0 or selected_end <= selected_start:
		extraction_ratio = 0.0
		return
	spectrum_x = (selected_start + selected_end) * 0.5
	extraction_ratio = clampf((selected_end - selected_start) / source_width, 0.0, 1.0)


func weight() -> float:
	return maxf(concentration * extraction_ratio, 0.0)


func tool_count(tool_id: StringName) -> int:
	return applied_tools.count(tool_id)
