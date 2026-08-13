class_name AlchemyRuntime
extends Control

signal request_close
signal batch_committed(potion_instance: Dictionary)

enum PanelMode {
	BREWING,
	PRODUCTION,
}

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
const DISTILLATION_FILL_PER_FULL_PUMP := 0.25
const DISTILLATION_BASE_SECONDS := 10.0
const DISTILLATION_MIN_SECONDS := 7.0
const DISTILLATION_MAX_SECONDS := 14.0
const BURNT_LIQUID_COLOR := Color(0.0, 0.0, 0.0, 0.90)

@export var ingredients: Array[IngredientData] = []
@export var potions: Array[PotionData] = []
@export var special_potions: Array[PotionData] = []
@export var failed_potion: PotionData
@export var default_heat_profile: HeatProfileData
@export_group("Shared Alchemy Background")
@export var pan_background_with_stage := true
@export var enable_standalone_console := true

var player_data: PlayerData
var night_result: NightResult
var day := 1
var temperature := 20.0
var active_prediction: Dictionary = {}
var last_brewed_instance: Dictionary = {}
var current_batch_reserved: Dictionary = {}
var production_reserved: Dictionary = {}
var processing_ingredient: ProcessedIngredient
var cauldron_ingredients: Array[ProcessedIngredient] = []
var last_prediction: Dictionary = {}
var powder_shelf_state := PowderShelfState.new()
var cauldron_powders: Dictionary = {}
var current_panel := PanelMode.BREWING
var _stage_tween: Tween
var standalone_developer_console: DeveloperConsole
var _distillation_fill_target := 0.0
var _distillation_completion_queued := false
var _distillation_total_seconds := DISTILLATION_BASE_SECONDS
var pending_bottling_instance: PotionInstanceData
var pending_bottling_potion: PotionData

var _ingredient_by_id: Dictionary = {}

@onready var horizontal_stage: Control = $StageRoot/HorizontalStage
@onready var stage_root: Control = $StageRoot
@onready var alchemy_background: Sprite2D = $AlchemyBackground
@onready var brewing_panel: Control = $StageRoot/HorizontalStage/BrewingPanel
@onready var production_panel: ProductionPanel = $StageRoot/HorizontalStage/ProductionPanel
@onready var unified_powder_shelf: PowderShelfView = %UnifiedPowderShelf
@onready var cauldron: CauldronDropZone = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/CauldronDropZone")
@onready var cauldron_water_art: TextureRect = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/CauldronWaterArt")
@onready var analyzer: SpectrumAnalyzer = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/SpectrumAnalyzer")
@onready var heat_controller: HeatController = $HeatController
@onready var temperature_gauge: TemperatureGauge = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/TemperatureControl")
@onready var temperature_slider: HSlider = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/TemperatureControl/TemperatureSlider")
@onready var temperature_value: Label = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/TemperatureControl/TemperatureValue")
@onready var bellows_control: BellowsControl = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/BellowsControl")
@onready var furnace_fire: FireTemperatureController = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/OVEN")
@onready var distillation_fill: DistillationFillController = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/DistillationDevice")
@onready var batch_list: VBoxContainer = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/BatchPanel/BatchMargin/IngredientList")
@onready var brew_button: Button = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/BrewButton")
@onready var cancel_button: Button = get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/CancelButton")
@onready var to_production_arrow: Button = $StageRoot/HorizontalStage/BrewingPanel/ArtBoard/ToProductionArrow
@onready var back_to_brewing_arrow: Button = $StageRoot/HorizontalStage/ProductionPanel/BackToBrewingArrow
@onready var bottling_panel: BottlingPanel = %BottlingPanel


func _ready() -> void:
	if stage_root != null and not stage_root.resized.is_connected(_sync_alchemy_background):
		stage_root.resized.connect(_sync_alchemy_background)
	_connect_button(brew_button, brew)
	_connect_button(cancel_button, cancel_batch)
	_connect_button(to_production_arrow, show_production_panel)
	_connect_button(back_to_brewing_arrow, show_brewing_panel)
	_connect_button(get_node_or_null("StageRoot/HorizontalStage/BrewingPanel/ArtBoard/ExitButton"), _request_close)
	if bottling_panel != null:
		bottling_panel.confirmed.connect(_on_bottling_confirmed)
	_build_lookup()
	if cauldron != null:
		cauldron.ingredient_dropped.connect(add_processing_to_cauldron)
		cauldron.powder_dropped.connect(add_powder_to_cauldron)
	if heat_controller != null:
		heat_controller.temperature_updated.connect(_on_heat_updated)
		heat_controller.brew_finished.connect(_on_heat_finished)
		heat_controller.temperature = temperature
		heat_controller.previous_temperature = temperature
	if bellows_control != null:
		bellows_control.bellows_pumped.connect(_on_bellows_pumped)
		bellows_control.set_pumping_enabled(false)
	if distillation_fill != null:
		distillation_fill.fill_animation_finished.connect(_on_distillation_fill_animation_finished)
	if temperature_slider != null:
		temperature_slider.set_value_no_signal(temperature)
	unified_powder_shelf.setup(powder_shelf_state)
	production_panel.setup(self, ingredients, powder_shelf_state)
	_update_navigation_arrows()
	_snap_to_current_panel()
	_refresh_ui()
	_sync_heat_ui()
	call_deferred("_sync_alchemy_background")
	call_deferred("_ensure_standalone_console")


func _process(_delta: float) -> void:
	_sync_alchemy_background()


func _sync_alchemy_background() -> void:
	if not pan_background_with_stage or alchemy_background == null or stage_root == null or horizontal_stage == null:
		return
	var background_texture := alchemy_background.texture
	if background_texture == null or stage_root.size.x <= 0.0:
		return
	var background_size := background_texture.get_size() * alchemy_background.scale.abs()
	if background_size.x <= 0.0:
		return
	var stage_width := stage_root.size.x
	var production_offset := production_panel.position.x if production_panel != null else stage_width
	var travel_progress := clampf(-horizontal_stage.position.x / maxf(production_offset, 0.001), 0.0, 1.0)
	# At brewing, the background's left edge is flush with the viewport.
	# At production, its right edge is flush with the viewport.
	var left_aligned_center := background_size.x * 0.5
	var right_aligned_center := stage_width - background_size.x * 0.5
	alchemy_background.position.x = lerpf(left_aligned_center, right_aligned_center, travel_progress)
	alchemy_background.position.y = stage_root.size.y * 0.5


func _ensure_standalone_console() -> void:
	if not enable_standalone_console or is_instance_valid(standalone_developer_console) or _night_runtime_ancestor() != null:
		return
	var console_scene := load("res://night/ui/developer_console/developer_console.tscn") as PackedScene
	if console_scene == null:
		push_error("Unable to load the standalone developer console.")
		return
	var console_layer := CanvasLayer.new()
	console_layer.name = "StandaloneDeveloperConsoleLayer"
	console_layer.layer = 220
	add_child(console_layer)
	standalone_developer_console = console_scene.instantiate() as DeveloperConsole
	console_layer.add_child(standalone_developer_console)
	standalone_developer_console.setup_alchemy(self)


func _night_runtime_ancestor() -> NightRuntime:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is NightRuntime:
			return ancestor as NightRuntime
		ancestor = ancestor.get_parent()
	return null


func _connect_button(button: BaseButton, callback: Callable) -> void:
	if button != null and not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func setup(shared_player_data: PlayerData, current_night_result: NightResult, current_day: int) -> void:
	player_data = shared_player_data
	night_result = current_night_result
	day = maxi(current_day, 1)
	if night_result == null:
		push_error("AlchemyRuntime requires NightRuntime's current NightResult.")
	_build_lookup()
	if production_panel != null:
		production_panel.setup(self, ingredients, powder_shelf_state)
	cancel_batch()


func ingredient_by_id(ingredient_id: StringName) -> IngredientData:
	return _ingredient_by_id.get(ingredient_id)


func reserve_production_ingredient(ingredient_id: StringName) -> bool:
	if available_count(ingredient_id) <= 0 or ingredient_by_id(ingredient_id) == null:
		return false
	production_reserved[ingredient_id] = int(production_reserved.get(ingredient_id, 0)) + 1
	_refresh_inventory_views()
	return true


func release_production_reservation(ingredient_id: StringName) -> void:
	var count := int(production_reserved.get(ingredient_id, 0))
	if count <= 1:
		production_reserved.erase(ingredient_id)
	else:
		production_reserved[ingredient_id] = count - 1
	_refresh_inventory_views()


func commit_production_powder(ingredient_id: StringName, powder: PowderInstanceData) -> bool:
	return commit_production_powder_batch({ingredient_id: 1}, powder)


func commit_production_powder_batch(ingredient_counts: Dictionary, powder: PowderInstanceData) -> bool:
	if night_result == null or powder == null or ingredient_counts.is_empty():
		return false
	for ingredient_key: Variant in ingredient_counts:
		var ingredient_id := StringName(str(ingredient_key))
		var count := int(ingredient_counts[ingredient_key])
		if count <= 0 or ingredient_by_id(ingredient_id) == null or int(production_reserved.get(ingredient_id, 0)) < count:
			return false
	if not powder_shelf_state.add_powder(powder):
		return false
	for ingredient_key: Variant in ingredient_counts:
		var ingredient_id := StringName(str(ingredient_key))
		var count := int(ingredient_counts[ingredient_key])
		night_result.spent_ingredients[ingredient_id] = int(night_result.spent_ingredients.get(ingredient_id, 0)) + count
		var remaining := int(production_reserved.get(ingredient_id, 0)) - count
		if remaining <= 0:
			production_reserved.erase(ingredient_id)
		else:
			production_reserved[ingredient_id] = remaining
	_refresh_inventory_views()
	return true


func show_production_panel() -> void:
	_slide_to_panel(PanelMode.PRODUCTION)


func show_brewing_panel() -> void:
	_slide_to_panel(PanelMode.BREWING)


func _slide_to_panel(mode: PanelMode) -> void:
	if current_panel == mode:
		return
	current_panel = mode
	if horizontal_stage == null or production_panel == null or unified_powder_shelf == null:
		return
	if production_panel != null:
		production_panel.cancel_piece_drag()
	_update_navigation_arrows()
	if _stage_tween != null and _stage_tween.is_running():
		_stage_tween.kill()
	var target_x := -production_panel.position.x if mode == PanelMode.PRODUCTION else 0.0
	var shelf_left := 0.015 if mode == PanelMode.PRODUCTION else 0.738
	var shelf_right := 0.275 if mode == PanelMode.PRODUCTION else 0.995
	_stage_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_stage_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_stage_tween.tween_property(horizontal_stage, "position:x", target_x, 0.45)
	_stage_tween.parallel().tween_property(unified_powder_shelf, "anchor_left", shelf_left, 0.45)
	_stage_tween.parallel().tween_property(unified_powder_shelf, "anchor_right", shelf_right, 0.45)


func _snap_to_current_panel() -> void:
	if horizontal_stage == null or production_panel == null or unified_powder_shelf == null:
		return
	horizontal_stage.position.x = -production_panel.position.x if current_panel == PanelMode.PRODUCTION else 0.0
	unified_powder_shelf.anchor_left = 0.015 if current_panel == PanelMode.PRODUCTION else 0.738
	unified_powder_shelf.anchor_right = 0.275 if current_panel == PanelMode.PRODUCTION else 0.995


func _update_navigation_arrows() -> void:
	if to_production_arrow != null:
		to_production_arrow.visible = current_panel == PanelMode.BREWING
	if back_to_brewing_arrow != null:
		back_to_brewing_arrow.visible = current_panel == PanelMode.PRODUCTION


func available_count(ingredient_id: StringName) -> int:
	if player_data == null:
		return 0
	return maxi(
		int(player_data.inventory.get(ingredient_id, 0))
		- int(night_result.spent_ingredients.get(ingredient_id, 0) if night_result != null else 0)
		- int(current_batch_reserved.get(ingredient_id, 0))
		- int(production_reserved.get(ingredient_id, 0)),
		0
	)


func reserve_ingredient(ingredient_id: StringName) -> bool:
	if is_brewing() or processing_ingredient != null:
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
	if is_brewing() or processing_ingredient == null:
		return false
	var changed := processing_ingredient.set_selection(start_x, end_x, MINIMUM_CUT_WIDTH)
	if changed:
		_refresh_prediction()
	return changed


func apply_tool(tool_id: StringName) -> bool:
	if is_brewing() or processing_ingredient == null:
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
	_refresh_prediction()
	return true


func add_processing_to_cauldron(processed: ProcessedIngredient = null) -> bool:
	if is_brewing():
		return false
	var candidate := processed if processed != null else processing_ingredient
	if candidate == null or candidate != processing_ingredient or candidate.weight() <= 0.0:
		return false
	cauldron_ingredients.append(candidate)
	processing_ingredient = null
	_refresh_ui()
	return true


func remove_from_cauldron(index: int) -> bool:
	if is_brewing() or index < 0 or index >= cauldron_ingredients.size() or processing_ingredient != null:
		return false
	var ingredient := cauldron_ingredients[index]
	cauldron_ingredients.remove_at(index)
	if cauldron_powders.has(ingredient):
		powder_shelf_state.return_powder(cauldron_powders[ingredient])
		cauldron_powders.erase(ingredient)
	else:
		processing_ingredient = ingredient
	_refresh_ui()
	return true


func add_powder_to_cauldron(instance_id: StringName) -> bool:
	if is_brewing():
		return false
	var powder := powder_shelf_state.take_powder(instance_id)
	if powder == null:
		return false
	var source := ingredient_by_id(powder.source_ingredient_id)
	if source == null:
		powder_shelf_state.return_powder(powder)
		return false
	var ingredient := ProcessedIngredient.from_ingredient(source)
	ingredient.spectrum_x = powder.spectrum_x
	ingredient.quality = powder.quality
	ingredient.special_potion_id = powder.special_potion_id
	ingredient.concentration = 1.0
	ingredient.extraction_ratio = powder.amount
	ingredient.applied_tools = [&"powder"]
	cauldron_ingredients.append(ingredient)
	cauldron_powders[ingredient] = powder
	_refresh_ui()
	return true


func set_temperature(value: float) -> void:
	temperature = clampf(value, 0.0, 100.0)
	if heat_controller != null:
		heat_controller.temperature = clampf(temperature, heat_controller.ambient_temperature, heat_controller.maximum_temperature)
		heat_controller.previous_temperature = heat_controller.temperature
	if temperature_slider != null and not is_equal_approx(temperature_slider.value, temperature):
		temperature_slider.set_value_no_signal(temperature)
	if temperature_value != null:
		temperature_value.text = "%d °C" % roundi(temperature)
	_refresh_prediction()
	_sync_heat_ui()


func pump_bellows() -> void:
	if bellows_control != null:
		bellows_control.pump_for_test()


func calculate_prediction() -> Dictionary:
	var all_materials: Array[ProcessedIngredient] = cauldron_ingredients.duplicate()
	if all_materials.is_empty():
		return {}
	var special_prediction := _calculate_special_prediction(all_materials)
	if not special_prediction.is_empty():
		return special_prediction
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
	var final_quality := average_quality * lerpf(0.70, 1.15, purity)
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


func _calculate_special_prediction(all_materials: Array[ProcessedIngredient]) -> Dictionary:
	var special_id := StringName()
	var total_weight := 0.0
	var weighted_quality := 0.0
	var has_special_material := false
	var contaminated := false
	for item: ProcessedIngredient in all_materials:
		if item == null:
			continue
		var item_weight := item.weight()
		if item_weight <= 0.0 or not is_finite(item_weight):
			continue
		total_weight += item_weight
		weighted_quality += item.quality * item_weight
		if item.special_potion_id == &"":
			contaminated = true
		else:
			has_special_material = true
			if special_id == &"":
				special_id = item.special_potion_id
			elif special_id != item.special_potion_id:
				contaminated = true
	if not has_special_material or total_weight < MINIMUM_BREW_WEIGHT:
		return {}
	if contaminated:
		return _failed_special_prediction(total_weight, weighted_quality)
	var potion := _special_potion_by_id(special_id)
	if potion == null:
		return _failed_special_prediction(total_weight, weighted_quality)
	return {
		"potion": potion,
		"potion_id": potion.id,
		"mixed_x": potion.spectrum_center_x,
		"main_effect_id": potion.main_effect_id,
		"secondary_effect_id": StringName(),
		"quality": clampf(weighted_quality / total_weight, 0.1, 1.5),
		"purity": 1.0,
		"total_weight": total_weight,
		"failed": false,
		"special_brew": true,
	}


func _failed_special_prediction(total_weight: float, weighted_quality: float) -> Dictionary:
	if failed_potion == null:
		return {}
	return {
		"potion": failed_potion,
		"potion_id": failed_potion.id,
		"mixed_x": 0.5,
		"main_effect_id": StringName(),
		"secondary_effect_id": StringName(),
		"quality": minf(clampf(weighted_quality / maxf(total_weight, MINIMUM_BREW_WEIGHT), 0.1, 1.5), 0.45),
		"purity": 0.0,
		"total_weight": total_weight,
		"failed": true,
		"special_brew": true,
	}


func _special_potion_by_id(potion_id: StringName) -> PotionData:
	for potion: PotionData in special_potions:
		if potion != null and potion.id == potion_id:
			return potion
	return null


func brew() -> Dictionary:
	if is_brewing() or pending_bottling_instance != null or night_result == null or cauldron_ingredients.is_empty():
		return {}
	var prediction := calculate_prediction()
	var profile := _heat_profile_for(prediction.get("potion"))
	if prediction.is_empty() or profile == null or heat_controller == null:
		return {}
	active_prediction = prediction.duplicate(true)
	if not heat_controller.start_brew(profile, false):
		active_prediction.clear()
		return {}
	_distillation_fill_target = 0.0
	_distillation_completion_queued = false
	_distillation_total_seconds = _distillation_duration_for(prediction)
	if distillation_fill != null:
		distillation_fill.stop_animation()
		distillation_fill.set_fill_progress(0.0)
		distillation_fill.set_liquid_color(_cauldron_liquid_color(prediction))
	if bellows_control != null:
		bellows_control.set_pumping_enabled(true)
	_refresh_prediction()
	_sync_heat_ui()
	return {"brewing": true}


func is_brewing() -> bool:
	return heat_controller != null and heat_controller.state == HeatController.HeatState.BREWING


func _on_heat_finished(heat_result: HeatResult) -> void:
	if heat_result.is_burned and distillation_fill != null:
		# Burning ends the brew immediately; freeze the current fill and show the
		# failed liquid instead of allowing the queued distillation animation to
		# finish with the original potion color.
		_distillation_completion_queued = false
		distillation_fill.stop_animation()
		distillation_fill.set_liquid_color(BURNT_LIQUID_COLOR)
	if bellows_control != null:
		bellows_control.set_pumping_enabled(false)
	_sync_heat_ui()
	if active_prediction.is_empty() or night_result == null:
		return
	var source_potion: PotionData = active_prediction.get("potion")
	var result_potion: PotionData = failed_potion if heat_result.is_burned else source_potion
	if result_potion == null:
		active_prediction.clear()
		return
	var instance := PotionInstanceData.new()
	instance.potion_id = result_potion.id
	instance.instance_uid = "brew-%s-%d-%d" % [result_potion.id, day, Time.get_ticks_usec()]
	instance.remaining_dose = 1.0
	instance.mixed_x = float(active_prediction.get("mixed_x", 0.0))
	instance.secondary_effect_id = (
		StringName(active_prediction.get("secondary_effect_id", ""))
		if not heat_result.is_burned and heat_result.preserve_secondary_effect
		else StringName()
	)
	instance.secondary_effect_multiplier = heat_result.secondary_effect_multiplier if instance.secondary_effect_id != &"" else 0.0
	instance.quality = clampf(float(active_prediction.get("quality", 0.1)) * heat_result.quality_multiplier, 0.1, 1.5)
	instance.potency = heat_result.potency_multiplier
	instance.duration = heat_result.duration_multiplier
	instance.price_multiplier = instance.quality * instance.potency * (1.0 + 0.15 * instance.secondary_effect_multiplier)
	instance.thermal_score = heat_result.thermal_score
	instance.temperature_grade = heat_result.temperature_grade()
	instance.was_burned = heat_result.is_burned
	instance.created_day = day
	var liquid_color := BURNT_LIQUID_COLOR if instance.was_burned else _cauldron_liquid_color(active_prediction)
	instance.actual_color = [liquid_color.r, liquid_color.g, liquid_color.b, liquid_color.a]
	if instance.was_burned:
		instance.bottle_style_id = &"black"
		_commit_brew_instance(instance, result_potion)
		bottling_panel.show_auto_stored(result_potion, instance.to_dict())
		return
	pending_bottling_instance = instance
	pending_bottling_potion = result_potion
	bottling_panel.open_for(result_potion, instance.to_dict())


func _commit_brew_instance(instance: PotionInstanceData, potion: PotionData) -> void:
	var instance_data := instance.to_dict()
	instance_data["potion_id"] = str(potion.id)
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
	if player_data != null:
		player_data.add_brewed_potion(instance_data)
	current_batch_reserved.clear()
	cauldron_ingredients.clear()
	cauldron_powders.clear()
	processing_ingredient = null
	active_prediction.clear()
	last_brewed_instance = instance_data.duplicate(true)
	batch_committed.emit(instance_data)
	_refresh_ui()


func _request_close() -> void:
	if not is_brewing() and pending_bottling_instance == null:
		request_close.emit()


func _on_bottling_confirmed(style_id: StringName, custom_name: String) -> void:
	if pending_bottling_instance == null or pending_bottling_potion == null:
		return
	pending_bottling_instance.bottle_style_id = style_id
	pending_bottling_instance.custom_name = custom_name
	var instance := pending_bottling_instance
	var potion := pending_bottling_potion
	pending_bottling_instance = null
	pending_bottling_potion = null
	_commit_brew_instance(instance, potion)


func cancel_batch() -> void:
	if is_brewing() or pending_bottling_instance != null:
		return
	for powder: PowderInstanceData in cauldron_powders.values():
		powder_shelf_state.return_powder(powder)
	cauldron_powders.clear()
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
	for potion: PotionData in special_potions:
		if potion == null or potion.id == &"":
			push_warning("AlchemyRuntime contains an invalid special PotionData reference.")


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


func _heat_profile_for(potion: PotionData) -> HeatProfileData:
	if potion != null and potion.heat_profile != null and potion.heat_profile.is_valid():
		return potion.heat_profile
	if default_heat_profile != null and default_heat_profile.is_valid():
		push_warning("Potion is missing a valid heat profile; using the explicit default profile.")
		return default_heat_profile
	push_warning("AlchemyRuntime has no valid heat profile for this brew.")
	return null


func _on_bellows_pumped(effective_strength: float) -> void:
	if not is_brewing() or heat_controller == null:
		return
	heat_controller.add_bellows_pump(effective_strength)
	if distillation_fill == null or bellows_control == null:
		push_error("AlchemyRuntime: DistillationDevice fill controller is required for bellows brewing.")
		return
	var normalized_pump := effective_strength / maxf(bellows_control.bellows_strength, 0.001)
	_distillation_fill_target = clampf(
		_distillation_fill_target + normalized_pump * DISTILLATION_FILL_PER_FULL_PUMP,
		0.0,
		1.0,
	)
	var remaining_fill := maxf(_distillation_fill_target - distillation_fill.fill_progress, 0.0)
	var fill_duration := maxf(remaining_fill * _distillation_total_seconds, 0.12)
	distillation_fill.animate_to(_distillation_fill_target, fill_duration)
	if is_equal_approx(_distillation_fill_target, 1.0):
		_distillation_completion_queued = true


func _on_distillation_fill_animation_finished(target_progress: float) -> void:
	if not _distillation_completion_queued or target_progress < 0.999 or not is_brewing():
		return
	_distillation_completion_queued = false
	if heat_controller != null:
		heat_controller.complete_brew()


func _cauldron_liquid_color(prediction: Dictionary) -> Color:
	var potion: PotionData = prediction.get("potion")
	if potion != null:
		var color := potion.display_color
		color.a = 0.62
		return color
	return Color(0.45, 0.62, 0.86, 0.62)


func _distillation_duration_for(prediction: Dictionary) -> float:
	var powder_amount := maxf(float(prediction.get("total_weight", 0.0)), 0.01)
	var amount_factor := clampf(0.75 + sqrt(powder_amount) * 0.35, 0.75, 1.35)
	var quality := clampf(float(prediction.get("quality", 1.0)), 0.1, 1.5)
	var quality_ratio := inverse_lerp(0.1, 1.5, quality)
	var quality_factor := lerpf(1.18, 0.84, quality_ratio)
	return clampf(
		DISTILLATION_BASE_SECONDS * amount_factor * quality_factor,
		DISTILLATION_MIN_SECONDS,
		DISTILLATION_MAX_SECONDS,
	)


func _on_heat_updated(next_temperature: float, fire_power: float) -> void:
	temperature = next_temperature
	_sync_heat_ui(fire_power)


func _sync_heat_ui(fire_power := -1.0) -> void:
	if heat_controller == null:
		return
	var current_fire := heat_controller.fire_power if fire_power < 0.0 else fire_power
	var profile := heat_controller.current_profile
	var ideal_ratio := heat_controller.time_in_ideal_range / maxf(heat_controller.brew_duration, 0.001)
	if temperature_gauge != null:
		temperature_gauge.set_heat_state(
			heat_controller.temperature,
			current_fire,
			profile,
			heat_controller.brew_elapsed,
			heat_controller.brew_duration,
			ideal_ratio,
		)
	if temperature_value != null:
		temperature_value.text = "%d °C" % roundi(heat_controller.temperature)
	if furnace_fire != null:
		furnace_fire.set_temperature(heat_controller.temperature)
	if cauldron_water_art != null:
		if heat_controller.state == HeatController.HeatState.BURNED:
			cauldron_water_art.modulate = Color(0.38, 0.31, 0.28, 1.0)
		else:
			var heat_ratio := clampf((heat_controller.temperature - heat_controller.ambient_temperature) / 80.0, 0.0, 1.0)
			cauldron_water_art.modulate = Color(
				lerpf(0.72, 1.18, heat_ratio),
				lerpf(0.78, 0.55, heat_ratio),
				lerpf(0.92, 0.46, heat_ratio),
				1.0,
			)


func _temperature_grade_name(grade: StringName) -> String:
	match grade:
		&"perfect_control": return "完美控温"
		&"stable_brew": return "稳定熬制"
		&"qualified": return "基本合格"
		&"unstable": return "温度失控"
		&"failed_extraction": return "萃取失败"
		_: return "烧焦"


func _refresh_ui() -> void:
	_refresh_inventory_views()
	if cauldron != null:
		cauldron.show_count(cauldron_ingredients.size())
	_refresh_batch_list()
	_refresh_prediction()


func _refresh_inventory_views() -> void:
	if production_panel != null:
		production_panel.refresh_inventory()


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
		brew_button.disabled = last_prediction.is_empty() or is_brewing()


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
