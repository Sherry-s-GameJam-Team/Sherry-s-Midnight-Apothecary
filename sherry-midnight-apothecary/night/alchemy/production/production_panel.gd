class_name ProductionPanel
extends Control

const HERB_ICON_COLUMNS := 4
const HERB_ICON_ROWS := 3
const HERB_PAGE_SIZE := HERB_ICON_COLUMNS * HERB_ICON_ROWS
# `herb_inventory.png` is 1792 × 2272. These gaps are measured between its
# painted 4 × 3 slots and are scaled with the artwork at runtime.
const HERB_ART_NATIVE_SIZE := Vector2(1792.0, 2272.0)
const HERB_SLOT_HORIZONTAL_GAP := 44.0
const HERB_SLOT_VERTICAL_GAP := 41.0

const DEFAULT_CATALOG_PATH := "res://night/ui/spectrum_codex/resources/default_potion_spectrum_catalog.tres"
const DEFAULT_UNLOCK_STATE_PATH := "res://night/ui/spectrum_codex/resources/default_potion_spectrum_unlock_state.tres"

@export var pack_delay_seconds := 3.0
@export var catalog: PotionSpectrumCatalog
@export var unlock_state: PotionSpectrumUnlockState

var alchemy_runtime: Node
var ingredient_definitions: Array[IngredientData] = []
var shelf_state: PowderShelfState
var current_herb: IngredientData
var current_source_instance_id: StringName
var source_herbs: Dictionary = {}
var pieces: Array[ProductionRuntimeTypes.HerbPieceRuntime] = []
var ground_powder: PowderInstanceData
var drag_mode := true
var packing := false
var drag_button: TextureButton
var herb_page := 0

@onready var herb_grid: GridContainer = %HerbGrid
@onready var herb_inventory_art: TextureRect = %HerbInventoryArt
@onready var herb_previous_button: Button = %HerbPreviousButton
@onready var herb_next_button: Button = %HerbNextButton
@onready var herb_page_label: Label = %HerbPageLabel
@onready var process_board: ProcessBoard = %ProcessBoard
@onready var spectrum_preview: ColorRect = %SpectrumPreview
@onready var spectrum_label: Label = %SpectrumLabel
@onready var paper_preview: TextureRect = %PaperPreview
@onready var powder_preview: TextureRect = %PowderPreview
@onready var status_label: Label = %StatusLabel
@onready var grab_mode_button: TextureButton = %GrabModeButton
@onready var separate_button: TextureButton = %SeparateButton
@onready var grind_button: TextureButton = %GrindButton
@onready var pack_button: TextureButton = %PackPowderButton
@onready var redo_button: TextureButton = %RedoButton
@onready var pack_timer: Timer = %PackTimer


func _ready() -> void:
	drag_button = grab_mode_button # Backwards-compatible script API for callers.
	if catalog == null and ResourceLoader.exists(DEFAULT_CATALOG_PATH):
		catalog = load(DEFAULT_CATALOG_PATH) as PotionSpectrumCatalog
	if unlock_state == null and ResourceLoader.exists(DEFAULT_UNLOCK_STATE_PATH):
		unlock_state = load(DEFAULT_UNLOCK_STATE_PATH) as PotionSpectrumUnlockState
	if unlock_state != null and not Engine.is_editor_hint():
		if not unlock_state.state_changed.is_connected(_on_unlock_state_changed):
			unlock_state.state_changed.connect(_on_unlock_state_changed)
	process_board.herb_dropped.connect(_on_herb_dropped)
	process_board.piece_moved.connect(_on_piece_moved)
	grab_mode_button.pressed.connect(toggle_grab_mode)
	separate_button.pressed.connect(separate_herb)
	grind_button.pressed.connect(grind_selected_pieces)
	pack_button.pressed.connect(pack_powder)
	redo_button.pressed.connect(redo_current_process)
	herb_previous_button.pressed.connect(show_previous_herb_page)
	herb_next_button.pressed.connect(show_next_herb_page)
	pack_timer.timeout.connect(_on_pack_timer_timeout)
	herb_inventory_art.resized.connect(_align_herb_grid_to_art)
	_align_herb_grid_to_art()
	_refresh_all()


func setup(runtime: Node, definitions: Array[IngredientData], state: PowderShelfState) -> void:
	alchemy_runtime = runtime
	ingredient_definitions = definitions
	shelf_state = state
	if alchemy_runtime != null and "spectrum_codex_panel" in alchemy_runtime and alchemy_runtime.spectrum_codex_panel != null:
		if unlock_state != null and unlock_state.state_changed.is_connected(_on_unlock_state_changed):
			unlock_state.state_changed.disconnect(_on_unlock_state_changed)
		catalog = alchemy_runtime.spectrum_codex_panel.catalog
		unlock_state = alchemy_runtime.spectrum_codex_panel.unlock_state
		if unlock_state != null and not Engine.is_editor_hint():
			if not unlock_state.state_changed.is_connected(_on_unlock_state_changed):
				unlock_state.state_changed.connect(_on_unlock_state_changed)
	_refresh_all()


func _on_unlock_state_changed() -> void:
	_refresh_color()


func set_drag_mode() -> void:
	if process_board != null and process_board.magnet_controller != null:
		process_board.magnet_controller.set_grab_mode(HerbMagnetController.GrabMode.SINGLE)
	drag_mode = true
	grab_mode_button.button_pressed = false
	grab_mode_button.tooltip_text = "单个抓取"


func toggle_grab_mode() -> void:
	if process_board == null or process_board.magnet_controller == null:
		return
	var multi := grab_mode_button.button_pressed
	process_board.magnet_controller.set_grab_mode(HerbMagnetController.GrabMode.MULTI_MAGNET if multi else HerbMagnetController.GrabMode.SINGLE)
	drag_mode = not multi
	grab_mode_button.tooltip_text = "长按左键，吸附范围内的全部部件" if multi else "单个抓取"
	grab_mode_button.modulate = Color(1.2, 1.12, 0.72, 1.0) if multi else Color.WHITE
	status_label.text = "多物体磁吸模式已开启。" if multi else "单个抓取模式已开启。"


func separate_herb() -> bool:
	if source_herbs.is_empty() or pieces.is_empty() or packing:
		return false
	var separated_count := 0
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.ATTACHED and piece.data != null and piece.data.detachable:
			piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED
			separated_count += 1
	status_label.text = "已摘离为 %d 个部位；可分别拖至废弃区或研磨区。" % separated_count
	_refresh_board()
	return separated_count > 0


func grind_selected_pieces() -> bool:
	if packing:
		return false
	process_board.reclassify_movable_pieces()
	var selected: Array[ProductionRuntimeTypes.HerbPieceRuntime] = []
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND:
			selected.append(piece)
	if selected.is_empty():
		status_label.text = "请先把至少一个部位拖到右侧研磨区。"
		return false
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in selected:
		piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.GROUND
	# Recalculate from every batch already ground from this source plant. This
	# keeps repeated grinding associative and avoids rounding drift.
	var total_weight := 0.0
	var weighted_x := 0.0
	var weighted_quality := 0.0
	var total_amount := 0.0
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state != ProductionRuntimeTypes.HerbPieceRuntime.State.GROUND:
			continue
		var weight := piece.weight()
		total_weight += weight
		weighted_x += piece.data.spectrum_x * weight
		weighted_quality += piece.quality * weight
		total_amount += piece.effective_yield()
	if total_weight <= 0.0:
		return false
	if ground_powder == null:
		ground_powder = PowderInstanceData.new()
		var primary_piece := selected[0]
		ground_powder.source_ingredient_id = primary_piece.source_ingredient.id if primary_piece.source_ingredient != null else current_herb.id
		ground_powder.source_instance_id = primary_piece.source_instance_id
	ground_powder.spectrum_x = clampf(weighted_x / total_weight, 0.0, 1.0)
	ground_powder.display_color = ProductionRuntimeTypes.spectrum_color(ground_powder.spectrum_x)
	ground_powder.quality = clampf((weighted_quality / total_weight) * 0.95, 0.1, 1.5)
	ground_powder.amount = clampf(total_amount, 0.01, 1.0)
	ground_powder.created_day = alchemy_runtime.day
	ground_powder.special_potion_id = _special_potion_for_ground_pieces()
	status_label.text = "本次研磨 %d 个部位：当前色值 %.3f，累计份量 %.0f%%。" % [
		selected.size(), ground_powder.spectrum_x, ground_powder.amount * 100.0,
	]
	_refresh_board()
	_refresh_color()
	return true


func _special_potion_for_ground_pieces() -> StringName:
	var found_ground_piece := false
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state != ProductionRuntimeTypes.HerbPieceRuntime.State.GROUND:
			continue
		found_ground_piece = true
		if piece.data == null or piece.data.id != &"dew_flask_herb_dew_flask":
			return &""
	return &"purification_potion" if found_ground_piece else &""


func pack_powder() -> bool:
	if packing:
		return false
	if ground_powder == null:
		if current_herb != null and _all_pieces_attached():
			redo_current_process()
			status_label.text = "整株药材尚未摘离，已自动回收且未消耗。"
		else:
			status_label.text = "没有已研磨粉末可装粉。"
		return false
	process_board.reclassify_movable_pieces()
	if _has_piece_on_workbench():
		status_label.text = "案板上仍有植物部位，请先移至研磨区或废弃区。"
		return false
	if _has_unprocessed_piece_in_grind_zone():
		status_label.text = "研磨区仍有未研磨部位，请先完成研磨。"
		return false
	process_board.formalize_waste()
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.GROUND:
			piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.PACKED
	packing = true
	paper_preview.visible = true
	powder_preview.visible = true
	powder_preview.modulate = ground_powder.display_color
	status_label.text = "正在装粉并静置 3 秒……"
	pack_timer.start(maxf(pack_delay_seconds, 0.01))
	return true


func complete_pack_immediately() -> bool:
	if ground_powder == null or current_herb == null or alchemy_runtime == null:
		return false
	pack_timer.stop()
	return _commit_current_powder()


func redo_current_process() -> void:
	pack_timer.stop()
	if alchemy_runtime != null:
		for source_herb: IngredientData in source_herbs.values():
			alchemy_runtime.release_production_reservation(source_herb.id)
	current_herb = null
	current_source_instance_id = &""
	source_herbs.clear()
	pieces.clear()
	ground_powder = null
	packing = false
	paper_preview.visible = false
	powder_preview.visible = false
	status_label.text = "当前加工流程已重做；已上架粉末不受影响。"
	_refresh_all()


func refresh_inventory() -> void:
	_refresh_herbs()


func herb_page_count() -> int:
	return maxi(1, ceili(float(_available_herb_definitions().size()) / float(HERB_PAGE_SIZE)))


func show_previous_herb_page() -> void:
	_set_herb_page(herb_page - 1)


func show_next_herb_page() -> void:
	_set_herb_page(herb_page + 1)


func _set_herb_page(page: int) -> void:
	var page_count := herb_page_count()
	herb_page = posmod(page, page_count)
	_refresh_herbs()


func _on_pack_timer_timeout() -> void:
	if not packing or ground_powder == null or current_herb == null:
		return
	_commit_current_powder()


func _commit_current_powder() -> bool:
	if ground_powder == null or current_herb == null:
		return false
	var packaged_powder_id := ground_powder.source_instance_id
	var package_start_rect := paper_preview.get_global_rect()
	if not alchemy_runtime.commit_production_powder_batch(_source_ingredient_counts(), ground_powder):
		packing = false
		status_label.text = "装粉提交失败，材料仍保留在加工台。"
		return false
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.PACKED:
			piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.SHELVED
	status_label.text = "粉末已自动放入左侧粉架。"
	current_herb = null
	current_source_instance_id = &""
	source_herbs.clear()
	pieces.clear()
	ground_powder = null
	packing = false
	paper_preview.visible = false
	powder_preview.visible = false
	if alchemy_runtime.unified_powder_shelf != null:
		alchemy_runtime.unified_powder_shelf.animate_item_from(packaged_powder_id, package_start_rect)
	_refresh_all()
	return true


func _on_herb_dropped(ingredient_id: StringName) -> void:
	if packing or alchemy_runtime == null:
		status_label.text = "正在装粉，暂时不能加入新药材。"
		return
	if alchemy_runtime != null and alchemy_runtime.tutorial_guide != null and alchemy_runtime.tutorial_guide.is_active:
		if ingredient_id != &"dew_flask_herb":
			status_label.text = "当前需制作湛蓝净化药水，请选择【露水水囊草】。"
			alchemy_runtime.tutorial_guide.show_wrong_herb_warning()
			return
	var data: IngredientData = alchemy_runtime.ingredient_by_id(ingredient_id)
	if data == null or not alchemy_runtime.reserve_production_ingredient(ingredient_id):
		status_label.text = "该药材当前没有可用库存。"
		return
	current_herb = data
	current_source_instance_id = StringName("%s_%d_%d" % [data.id, alchemy_runtime.day, Time.get_ticks_usec()])
	source_herbs[current_source_instance_id] = data
	pieces.append_array(ProductionRuntimeTypes.create_piece_set(
		data,
		current_source_instance_id,
		ProductionRuntimeTypes.HerbPieceRuntime.State.ATTACHED
	))
	status_label.text = "%s 已加入加工板；当前批次共 %d 株药材。" % [data.display_name, source_herbs.size()]
	_refresh_all()


func _on_piece_moved(piece: ProductionRuntimeTypes.HerbPieceRuntime, target_state: int) -> void:
	if packing or piece == null or piece.state not in [
		ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED,
		ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE,
		ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND,
	]:
		return
	if target_state == ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND and not piece.data.grindable:
		return
	piece.state = target_state
	process_board.update_piece_visual(piece)


func cancel_piece_drag() -> void:
	if process_board != null:
		process_board.cancel_active_drags()


func _refresh_all() -> void:
	_refresh_herbs()
	_refresh_board()
	_refresh_color()


func _all_pieces_attached() -> bool:
	if pieces.is_empty():
		return false
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state != ProductionRuntimeTypes.HerbPieceRuntime.State.ATTACHED:
			return false
	return true


func _has_piece_on_workbench() -> bool:
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state in [
			ProductionRuntimeTypes.HerbPieceRuntime.State.ATTACHED,
			ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED,
		]:
			return true
	return false


func _has_unprocessed_piece_in_grind_zone() -> bool:
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND:
			return true
	return false


func _source_ingredient_counts() -> Dictionary:
	var counts: Dictionary = {}
	for source_herb: IngredientData in source_herbs.values():
		counts[source_herb.id] = int(counts.get(source_herb.id, 0)) + 1
	return counts


func _refresh_herbs() -> void:
	if herb_grid == null:
		return
	_align_herb_grid_to_art()
	var available_definitions := _available_herb_definitions()
	var page_count := maxi(1, ceili(float(available_definitions.size()) / float(HERB_PAGE_SIZE)))
	herb_page = clampi(herb_page, 0, page_count - 1)
	var first_index := herb_page * HERB_PAGE_SIZE
	var visible_definitions: Array[IngredientData] = []
	for index in range(first_index, mini(first_index + HERB_PAGE_SIZE, available_definitions.size())):
		visible_definitions.append(available_definitions[index])
	var current_cards: Dictionary = {}
	var current_card_order: Array[StringName] = []
	for child: Node in herb_grid.get_children():
		if child is HerbCard:
			var card := child as HerbCard
			if card.ingredient_data != null and not current_cards.has(card.ingredient_data.id):
				current_cards[card.ingredient_data.id] = card
				current_card_order.append(card.ingredient_data.id)
	var can_update_in_place := current_cards.size() == visible_definitions.size()
	if can_update_in_place:
		for index in visible_definitions.size():
			var ingredient := visible_definitions[index]
			if not current_cards.has(ingredient.id) or current_card_order[index] != ingredient.id:
				can_update_in_place = false
				break
	if can_update_in_place:
		for ingredient: IngredientData in visible_definitions:
			var card := current_cards[ingredient.id] as HerbCard
			card.update_available(alchemy_runtime.available_count(ingredient.id) if alchemy_runtime != null else 0)
		_update_herb_page_controls(page_count)
		return
	for child: Node in herb_grid.get_children():
		child.free()
	for ingredient: IngredientData in visible_definitions:
		var card := HerbCard.new()
		card.compact_visual = true
		card.compact_icon = ingredient.icon
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.setup(ingredient, alchemy_runtime.available_count(ingredient.id) if alchemy_runtime != null else 0)
		herb_grid.add_child(card)
	while herb_grid.get_child_count() < HERB_PAGE_SIZE:
		var empty_slot := Control.new()
		empty_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		herb_grid.add_child(empty_slot)
	_update_herb_page_controls(page_count)


func _available_herb_definitions() -> Array[IngredientData]:
	var definitions: Array[IngredientData] = []
	for ingredient: IngredientData in ingredient_definitions:
		if ingredient != null:
			definitions.append(ingredient)
	return definitions


func _update_herb_page_controls(page_count: int) -> void:
	if herb_page_label != null:
		herb_page_label.text = "%d / %d" % [herb_page + 1, page_count]
	if herb_previous_button != null:
		herb_previous_button.visible = page_count > 1
	if herb_next_button != null:
		herb_next_button.visible = page_count > 1


func _align_herb_grid_to_art() -> void:
	if herb_grid == null or herb_inventory_art == null:
		return
	var horizontal_gap := roundi(herb_inventory_art.size.x / HERB_ART_NATIVE_SIZE.x * HERB_SLOT_HORIZONTAL_GAP)
	var vertical_gap := roundi(herb_inventory_art.size.y / HERB_ART_NATIVE_SIZE.y * HERB_SLOT_VERTICAL_GAP)
	herb_grid.add_theme_constant_override("h_separation", horizontal_gap)
	herb_grid.add_theme_constant_override("v_separation", vertical_gap)


func _refresh_board() -> void:
	if process_board != null:
		process_board.show_state(current_herb, pieces)


func _get_band_for_spectrum(x: float) -> PotionSpectrumBand:
	if catalog == null or catalog.bands.is_empty():
		return null
	for band in catalog.bands:
		if band != null and x >= band.spectrum_min and x <= band.spectrum_max:
			return band
	var min_dist := INF
	var nearest_band: PotionSpectrumBand = null
	for band in catalog.bands:
		if band != null:
			var dist := 0.0
			if x < band.spectrum_min:
				dist = band.spectrum_min - x
			elif x > band.spectrum_max:
				dist = x - band.spectrum_max
			if dist < min_dist:
				min_dist = dist
				nearest_band = band
	return nearest_band


func _get_closest_function(band: PotionSpectrumBand, x: float) -> PotionFunctionDefinition:
	if catalog == null or band == null:
		return null
	var closest: PotionFunctionDefinition = null
	var min_dist := INF
	for f in catalog.functions:
		if f != null and f.band_id == band.id:
			var dist := absf(x - f.spectrum_position)
			if dist < min_dist:
				min_dist = dist
				closest = f
	return closest


func _refresh_color() -> void:
	var mixed_x := -1.0
	if ground_powder != null:
		mixed_x = ground_powder.spectrum_x
	if mixed_x < 0.0:
		spectrum_preview.color = Color(0.42, 0.36, 0.28, 0.55)
		spectrum_label.text = "等待加工结果"
	else:
		spectrum_preview.color = ProductionRuntimeTypes.spectrum_color(mixed_x)
		var band := _get_band_for_spectrum(mixed_x)
		var func_def := _get_closest_function(band, mixed_x)
		var is_unlocked := false
		if func_def != null and unlock_state != null:
			is_unlocked = unlock_state.is_function_unlocked(func_def.id)

		if is_unlocked and band != null and not band.primary_effect_name.is_empty():
			spectrum_label.text = "当前色值 %.3f · 功效：%s" % [mixed_x, band.primary_effect_name]
		else:
			spectrum_label.text = "当前色值 %.3f · 未知功效" % mixed_x
