class_name SpectrumVerticalView
extends Control

signal band_selected(band: PotionSpectrumBand)
signal function_selected(function: PotionFunctionDefinition)
signal recipe_selected(recipe: PotionRecipeDefinition)
signal zoom_changed(zoom_factor: float)

var current_zoom: float = 1.0
var catalog_ref: PotionSpectrumCatalog = null
var unlock_state_ref: PotionSpectrumUnlockState = null

var is_dragging: bool = false
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_content_pos: Vector2 = Vector2.ZERO

var band_items: Array[SpectrumBandItem] = []

const BAND_ITEM_SCENE := preload("res://night/ui/spectrum_codex/scenes/spectrum_band_item.tscn")
const SPECTRUM_RIBBON_BAR_SCRIPT := preload("res://night/ui/spectrum_codex/scripts/spectrum_ribbon_bar.gd")
const SCROLL_SPEED: int = 54

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var content_margin: MarginContainer = $ScrollContainer/ContentMargin
@onready var ribbon_bar: Control = $ScrollContainer/ContentMargin/HBox/SpectrumRibbonBar
@onready var bands_container: VBoxContainer = $ScrollContainer/ContentMargin/HBox/BandsContainer


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if scroll_container:
		scroll_container.gui_input.connect(_on_gui_input)
	if bands_container:
		bands_container.sort_children.connect(_on_bands_layout_changed)
	if ribbon_bar:
		ribbon_bar.band_clicked.connect(func(band: PotionSpectrumBand) -> void:
			_highlight_selected_band(band.id)
			band_selected.emit(band)
		)
		if ribbon_bar.has_signal("function_clicked"):
			ribbon_bar.connect("function_clicked", func(func_def: PotionFunctionDefinition) -> void:
				_highlight_selected_function(func_def.id)
				function_selected.emit(func_def)
			)


func setup(catalog: PotionSpectrumCatalog, unlock_state: PotionSpectrumUnlockState) -> void:
	catalog_ref = catalog
	unlock_state_ref = unlock_state
	_rebuild_bands()


func refresh() -> void:
	if catalog_ref != null:
		_rebuild_bands()


func _rebuild_bands() -> void:
	if bands_container == null or catalog_ref == null:
		return

	for child in bands_container.get_children():
		child.queue_free()
	band_items.clear()

	var sorted_bands: Array[PotionSpectrumBand] = catalog_ref.get_bands_sorted()
	if ribbon_bar and ribbon_bar.has_method("setup_bands"):
		ribbon_bar.setup_bands(sorted_bands)

	for band in sorted_bands:
		var band_item := BAND_ITEM_SCENE.instantiate() as SpectrumBandItem
		bands_container.add_child(band_item)
		var functions: Array[PotionFunctionDefinition] = catalog_ref.get_functions_for_band(band.id)
		band_item.setup(band, functions, catalog_ref, unlock_state_ref)
		band_item.set_lod_level(2)

		band_item.band_clicked.connect(func(b: PotionSpectrumBand) -> void:
			_highlight_selected_band(b.id)
			band_selected.emit(b)
		)
		band_item.function_clicked.connect(func(f: PotionFunctionDefinition) -> void:
			_highlight_selected_function(f.id)
			function_selected.emit(f)
		)
		band_item.recipe_clicked.connect(func(r: PotionRecipeDefinition) -> void:
			_highlight_selected_recipe(r.id)
			recipe_selected.emit(r)
		)
		band_items.append(band_item)

	call_deferred("update_ribbon_anchors")


func update_ribbon_anchors() -> void:
	if ribbon_bar == null or bands_container == null:
		return

	var b_anchors: Array[Dictionary] = []
	var f_anchors: Array[Dictionary] = []

	for item in band_items:
		if item == null or not is_instance_valid(item):
			continue
		var top_y: float = item.position.y
		var bot_y: float = item.position.y + item.size.y
		var center_y: float = top_y + 20.0
		if item.header_button and item.header_button.is_inside_tree():
			center_y = top_y + item.header_button.position.y + item.header_button.size.y * 0.5

		b_anchors.append({
			"band": item.band_data,
			"top_y": top_y,
			"bottom_y": bot_y,
			"center_y": center_y
		})

		# Collect independent function indicators
		if item.function_items.size() > 0:
			for f_item in item.function_items:
				if f_item == null or not is_instance_valid(f_item) or not f_item.visible:
					continue
				var f_center_y: float = top_y + item.indent_margin.position.y + item.functions_box.position.y + f_item.position.y + f_item.size.y * 0.5
				f_anchors.append({
					"function": f_item.function_data,
					"band": item.band_data,
					"center_y": f_center_y,
					"is_unlocked": f_item.is_unlocked
				})

	if ribbon_bar.has_method("set_band_anchors"):
		ribbon_bar.set_band_anchors(b_anchors, f_anchors)


func _on_bands_layout_changed() -> void:
	update_ribbon_anchors()


func scroll_to_y(target_y: float) -> void:
	if scroll_container:
		scroll_container.scroll_vertical = int(round(target_y))


func scroll_by(delta_y: int) -> void:
	if scroll_container:
		scroll_container.scroll_vertical += delta_y


func reset_view() -> void:
	if scroll_container:
		scroll_container.scroll_vertical = 0
		scroll_container.scroll_horizontal = 0


# Compatibility helpers
func set_zoom(_new_zoom: float) -> void:
	pass


func zoom_at_position(_new_zoom: float, _focus_pos: Vector2) -> void:
	pass


func zoom_in() -> void:
	scroll_by(-SCROLL_SPEED)


func zoom_out() -> void:
	scroll_by(SCROLL_SPEED)


func focus_recipe(recipe_id: StringName) -> bool:
	for item in band_items:
		if item.focus_recipe(recipe_id):
			if item.band_data:
				_highlight_selected_band(item.band_data.id)
			return true
	return false


func focus_function(func_id: StringName) -> bool:
	for item in band_items:
		if item.focus_function(func_id):
			_highlight_selected_function(func_id)
			return true
	return false


func _highlight_selected_band(band_id: StringName) -> void:
	if ribbon_bar and ribbon_bar.has_method("set_selected_band"):
		ribbon_bar.set_selected_band(band_id)
	for item in band_items:
		item.set_selected(item.band_data != null and item.band_data.id == band_id)


func _highlight_selected_function(func_id: StringName) -> void:
	var target_band_id: StringName = &""
	for item in band_items:
		if item.focus_function(func_id):
			if item.band_data:
				target_band_id = item.band_data.id
	if ribbon_bar and ribbon_bar.has_method("set_selected_function"):
		ribbon_bar.set_selected_function(func_id, target_band_id)


func _highlight_selected_recipe(recipe_id: StringName) -> void:
	for item in band_items:
		if item.focus_recipe(recipe_id):
			if item.band_data:
				_highlight_selected_band(item.band_data.id)


func _handle_mouse_button(mb: InputEventMouseButton, from_gui: bool = false) -> void:
	var viewport_rect := scroll_container.get_global_rect() if scroll_container else Rect2()
	var is_mouse_over: bool = from_gui or (viewport_rect.size == Vector2.ZERO) or viewport_rect.has_point(mb.global_position)
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		if is_mouse_over and scroll_container:
			scroll_container.scroll_vertical -= SCROLL_SPEED
			get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if is_mouse_over and scroll_container:
			scroll_container.scroll_vertical += SCROLL_SPEED
			get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE:
		if mb.is_pressed():
			if is_mouse_over:
				is_dragging = true
				drag_start_mouse_pos = mb.global_position
				if scroll_container:
					drag_start_content_pos = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
		else:
			is_dragging = false


func _handle_mouse_motion(mm: InputEventMouseMotion) -> void:
	if is_dragging and scroll_container:
		var delta: Vector2 = mm.global_position - drag_start_mouse_pos
		scroll_container.scroll_horizontal = int(drag_start_content_pos.x - delta.x)
		scroll_container.scroll_vertical = int(drag_start_content_pos.y - delta.y)


func _input(event: InputEvent) -> void:
	if not visible or scroll_container == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton, false)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton, true)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
