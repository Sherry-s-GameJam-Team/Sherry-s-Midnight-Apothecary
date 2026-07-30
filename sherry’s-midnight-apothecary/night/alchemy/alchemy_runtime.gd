class_name AlchemyRuntime
extends Control

signal request_close
signal batch_committed(potion_instance: Dictionary)

const MINIMUM_CUT_WIDTH := 0.01
const MINIMUM_BREW_WEIGHT := 0.001
const GRIND_CONCENTRATION := 1.20
const GRIND_QUALITY := 0.95
const DISTILL_WIDTH := 0.65
const DISTILL_CONCENTRATION := 1.15
const DISTILL_QUALITY := 1.05
const DILUTE_CONCENTRATION := 0.75
const DILUTE_QUALITY := 1.03
const MAX_DILUTIONS := 3

@export var ingredients: Array[IngredientData] = []
@export var potions: Array[PotionData] = []
@export var failed_potion: PotionData

var player_data: PlayerData
var night_result: NightResult
var day := 1
var temperature := 55.0
var current_batch_reserved: Dictionary = {}
var processing_ingredient: ProcessedIngredient
var cauldron_ingredients: Array[ProcessedIngredient] = []
var last_prediction: Dictionary = {}

var _ingredient_by_id: Dictionary = {}

@onready var herb_grid: GridContainer = get_node_or_null("ArtBoard/HerbInventoryPanel/HerbMargin/HerbGrid")
@onready var processor: IngredientProcessor = get_node_or_null("ArtBoard/IngredientProcessor")
@onready var cauldron: CauldronDropZone = get_node_or_null("ArtBoard/CauldronDropZone")
@onready var analyzer: SpectrumAnalyzer = get_node_or_null("ArtBoard/SpectrumAnalyzer")
@onready var temperature_slider: HSlider = get_node_or_null("ArtBoard/TemperatureControl/TemperatureSlider")
@onready var temperature_value: Label = get_node_or_null("ArtBoard/TemperatureControl/TemperatureValue")
@onready var batch_list: VBoxContainer = get_node_or_null("ArtBoard/BatchPanel/BatchMargin/IngredientList")
@onready var brew_button: Button = get_node_or_null("ArtBoard/BrewButton")
@onready var result_popup: AcceptDialog = get_node_or_null("ResultPopup")


func _ready() -> void:
	_build_lookup()
	if processor != null:
		processor.herb_dropped.connect(_on_herb_dropped)
		processor.selection_changed.connect(set_processing_selection)
		processor.tool_requested.connect(apply_tool)
	if cauldron != null:
		cauldron.ingredient_dropped.connect(add_processing_to_cauldron)
	if temperature_slider != null:
		temperature_slider.value_changed.connect(set_temperature)
		temperature_slider.value = temperature
	_refresh_ui()


func setup(shared_player_data: PlayerData, current_night_result: NightResult, current_day: int) -> void:
	player_data = shared_player_data
	night_result = current_night_result
	day = maxi(current_day, 1)
	if night_result == null:
		push_error("AlchemyRuntime requires NightRuntime's current NightResult.")
	_build_lookup()
	cancel_batch()


func available_count(ingredient_id: StringName) -> int:
	if player_data == null:
		return 0
	return maxi(
		int(player_data.inventory.get(ingredient_id, 0))
		- int(night_result.spent_ingredients.get(ingredient_id, 0) if night_result != null else 0)
		- int(current_batch_reserved.get(ingredient_id, 0)),
		0
	)


func reserve_ingredient(ingredient_id: StringName) -> bool:
	if processing_ingredient != null:
		push_warning("Finish the current ingredient before processing another.")
		return false
	var data: IngredientData = _ingredient_by_id.get(ingredient_id)
	if data == null or data.spectrum_start >= data.spectrum_end:
		push_warning("Invalid ingredient data: %s" % ingredient_id)
		return false
	if available_count(ingredient_id) <= 0:
		push_warning("No available inventory for: %s" % ingredient_id)
		return false
	var processed := ProcessedIngredient.from_ingredient(data)
	if processed == null:
		return false
	current_batch_reserved[ingredient_id] = int(current_batch_reserved.get(ingredient_id, 0)) + 1
	processing_ingredient = processed
	_refresh_ui()
	return true


func set_processing_selection(start_x: float, end_x: float) -> bool:
	if processing_ingredient == null:
		return false
	var changed := processing_ingredient.set_selection(start_x, end_x, MINIMUM_CUT_WIDTH)
	if changed:
		_refresh_prediction()
	return changed


func apply_tool(tool_id: StringName) -> bool:
	if processing_ingredient == null:
		return false
	match tool_id:
		&"grind":
			if processing_ingredient.tool_count(tool_id) >= 1:
				return false
			processing_ingredient.concentration *= GRIND_CONCENTRATION
			processing_ingredient.quality *= GRIND_QUALITY
		&"distill":
			if processing_ingredient.tool_count(tool_id) >= 1:
				return false
			var half_width := (processing_ingredient.selected_end - processing_ingredient.selected_start) * DISTILL_WIDTH * 0.5
			processing_ingredient.selected_start = processing_ingredient.spectrum_x - half_width
			processing_ingredient.selected_end = processing_ingredient.spectrum_x + half_width
			processing_ingredient.concentration *= DISTILL_CONCENTRATION
			processing_ingredient.quality *= DISTILL_QUALITY
			processing_ingredient.recalculate()
		&"dilute":
			if processing_ingredient.tool_count(tool_id) >= MAX_DILUTIONS:
				return false
			processing_ingredient.concentration *= DILUTE_CONCENTRATION
			processing_ingredient.quality *= DILUTE_QUALITY
		_:
			return false
	processing_ingredient.concentration = clampf(processing_ingredient.concentration, 0.05, 2.0)
	processing_ingredient.quality = clampf(processing_ingredient.quality, 0.1, 1.5)
	processing_ingredient.applied_tools.append(tool_id)
	if processor != null:
		processor.show_ingredient(processing_ingredient)
	_refresh_prediction()
	return true


func add_processing_to_cauldron(processed: ProcessedIngredient = null) -> bool:
	var candidate := processed if processed != null else processing_ingredient
	if candidate == null or candidate != processing_ingredient or candidate.weight() <= 0.0:
		return false
	cauldron_ingredients.append(candidate)
	processing_ingredient = null
	_refresh_ui()
	return true


func remove_from_cauldron(index: int) -> bool:
	if index < 0 or index >= cauldron_ingredients.size() or processing_ingredient != null:
		return false
	processing_ingredient = cauldron_ingredients[index]
	cauldron_ingredients.remove_at(index)
	_refresh_ui()
	return true


func set_temperature(value: float) -> void:
	temperature = clampf(value, 0.0, 100.0)
	if temperature_value != null:
		temperature_value.text = "%d °C" % roundi(temperature)
	_refresh_prediction()


func calculate_prediction() -> Dictionary:
	var all_materials: Array[ProcessedIngredient] = cauldron_ingredients.duplicate()
	if all_materials.is_empty():
		return {}
	var total_weight := 0.0
	var weighted_x := 0.0
	var weighted_quality := 0.0
	var contributions: Dictionary = {}
	for item: ProcessedIngredient in all_materials:
		if item == null:
			continue
		var item_weight := item.weight()
		if item_weight <= 0.0 or not is_finite(item_weight):
			continue
		total_weight += item_weight
		weighted_x += item.spectrum_x * item_weight
		weighted_quality += item.quality * item_weight
		var nearest := _nearest_potion(item.spectrum_x)
		if nearest != null:
			contributions[nearest.id] = float(contributions.get(nearest.id, 0.0)) + item_weight
	if total_weight < MINIMUM_BREW_WEIGHT:
		return {}
	var mixed_x := clampf(weighted_x / total_weight, 0.0, 1.0)
	var main := _potion_for_mixed_x(mixed_x)
	var failed := main == null
	if failed:
		main = failed_potion
	if main == null:
		return {}
	var main_contribution := float(contributions.get(main.id, 0.0))
	var purity := clampf(main_contribution / total_weight, 0.0, 1.0) if not failed else 0.0
	var secondary_effect := StringName()
	if not failed:
		var second := _secondary_potion(contributions, main.id)
		if second != null and float(contributions.get(second.id, 0.0)) / total_weight >= 0.20:
			secondary_effect = second.main_effect_id
	var average_quality := weighted_quality / total_weight
	var final_quality := average_quality * lerpf(0.70, 1.15, purity) * _temperature_modifier()
	final_quality = clampf(final_quality, 0.1, 1.5)
	if failed:
		final_quality = minf(final_quality, 0.45)
	return {
		"potion": main,
		"potion_id": main.id,
		"mixed_x": mixed_x,
		"main_effect_id": main.main_effect_id if not failed else StringName(),
		"secondary_effect_id": secondary_effect,
		"quality": final_quality,
		"purity": purity,
		"total_weight": total_weight,
		"failed": failed,
	}


func brew() -> Dictionary:
	if night_result == null or cauldron_ingredients.is_empty():
		return {}
	var prediction := calculate_prediction()
	if prediction.is_empty():
		return {}
	var instance := PotionInstanceData.new()
	instance.potion_id = prediction["potion_id"]
	instance.mixed_x = prediction["mixed_x"]
	instance.secondary_effect_id = prediction["secondary_effect_id"]
	instance.quality = prediction["quality"]
	instance.created_day = day
	var instance_data := instance.to_dict()
	for ingredient_key: Variant in current_batch_reserved:
		var ingredient_id := StringName(str(ingredient_key))
		night_result.spent_ingredients[ingredient_id] = (
			int(night_result.spent_ingredients.get(ingredient_id, 0))
			+ int(current_batch_reserved[ingredient_key])
		)
	var potion_id: StringName = instance.potion_id
	var produced: Array = night_result.produced_potions.get(potion_id, [])
	produced.append(instance_data)
	night_result.produced_potions[potion_id] = produced
	current_batch_reserved.clear()
	cauldron_ingredients.clear()
	processing_ingredient = null
	batch_committed.emit(instance_data)
	if result_popup != null:
		var potion: PotionData = prediction["potion"]
		result_popup.dialog_text = "%s\n品质：%s（%.2f）" % [
			potion.display_name,
			_quality_name(instance.quality),
			instance.quality,
		]
		result_popup.popup_centered()
	_refresh_ui()
	return instance_data


func cancel_batch() -> void:
	current_batch_reserved.clear()
	cauldron_ingredients.clear()
	processing_ingredient = null
	_refresh_ui()


func _build_lookup() -> void:
	_ingredient_by_id.clear()
	for data: IngredientData in ingredients:
		if data == null or data.id == &"" or data.spectrum_start >= data.spectrum_end:
			push_warning("AlchemyRuntime ignored invalid IngredientData.")
			continue
		_ingredient_by_id[data.id] = data
	for potion: PotionData in potions:
		if potion == null:
			push_warning("AlchemyRuntime contains an empty PotionData reference.")
			continue
		for effect_range: Vector2 in potion.effect_ranges:
			if effect_range.x < 0.0 or effect_range.y > 1.0 or effect_range.x > effect_range.y:
				push_warning("Invalid effect range in %s." % potion.id)


func _nearest_potion(spectrum_x: float) -> PotionData:
	var nearest: PotionData
	var nearest_distance := INF
	for potion: PotionData in potions:
		if potion == null:
			continue
		var distance := absf(spectrum_x - potion.spectrum_center_x)
		if distance < nearest_distance:
			nearest = potion
			nearest_distance = distance
	return nearest


func _potion_for_mixed_x(mixed_x: float) -> PotionData:
	var best: PotionData
	var best_distance := INF
	for potion: PotionData in potions:
		if potion == null:
			continue
		var hits := false
		for effect_range: Vector2 in potion.effect_ranges:
			if effect_range.x <= effect_range.y and mixed_x >= effect_range.x and mixed_x <= effect_range.y:
				hits = true
				break
		if hits:
			var distance := absf(mixed_x - potion.spectrum_center_x)
			if distance < best_distance:
				best = potion
				best_distance = distance
	return best


func _secondary_potion(contributions: Dictionary, main_id: StringName) -> PotionData:
	var largest: PotionData
	var largest_value := -1.0
	var second: PotionData
	var second_value := -1.0
	for potion: PotionData in potions:
		if potion == null:
			continue
		var value := float(contributions.get(potion.id, 0.0))
		if value > largest_value:
			second = largest
			second_value = largest_value
			largest = potion
			largest_value = value
		elif value > second_value:
			second = potion
			second_value = value
	if second == null or second.id == main_id or second_value <= 0.0:
		return null
	return second


func _temperature_modifier() -> float:
	if temperature >= 45.0 and temperature <= 65.0:
		return 1.0
	var distance := 45.0 - temperature if temperature < 45.0 else temperature - 65.0
	return maxf(0.65, 1.0 - distance * 0.01)


func _refresh_ui() -> void:
	_refresh_inventory()
	if processor != null:
		processor.show_ingredient(processing_ingredient)
	if cauldron != null:
		cauldron.show_count(cauldron_ingredients.size())
	_refresh_batch_list()
	_refresh_prediction()


func _refresh_inventory() -> void:
	if herb_grid == null:
		return
	for child: Node in herb_grid.get_children():
		child.queue_free()
	for data: IngredientData in ingredients:
		if data == null:
			continue
		var card := HerbCard.new()
		card.compact_visual = true
		card.custom_minimum_size = Vector2(82, 102)
		card.setup(data, available_count(data.id))
		herb_grid.add_child(card)


func _refresh_batch_list() -> void:
	if batch_list == null:
		return
	for child: Node in batch_list.get_children():
		child.queue_free()
	for index in cauldron_ingredients.size():
		var row := HBoxContainer.new()
		var label := Label.new()
		var item := cauldron_ingredients[index]
		label.text = "%s  x=%.2f" % [item.source_data.display_name, item.spectrum_x]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var remove_button := Button.new()
		remove_button.text = "取回"
		remove_button.pressed.connect(remove_from_cauldron.bind(index))
		row.add_child(label)
		row.add_child(remove_button)
		batch_list.add_child(row)


func _refresh_prediction() -> void:
	last_prediction = calculate_prediction()
	if analyzer != null:
		analyzer.set_prediction(last_prediction)
	if brew_button != null:
		brew_button.disabled = last_prediction.is_empty()


func _quality_name(value: float) -> String:
	if value < 0.5:
		return "粗劣"
	if value < 0.8:
		return "普通"
	if value < 1.1:
		return "优良"
	if value < 1.3:
		return "卓越"
	return "完美"


func _on_herb_dropped(ingredient_id: StringName) -> void:
	reserve_ingredient(ingredient_id)
