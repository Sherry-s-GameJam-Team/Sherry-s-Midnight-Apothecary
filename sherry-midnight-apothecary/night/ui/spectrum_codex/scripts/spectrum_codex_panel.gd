class_name SpectrumCodexPanel
extends Control

signal recipe_selected(recipe_id: StringName)
signal function_selected(function_id: StringName)
signal view_mode_changed(mode: StringName)
signal request_close()

@export var catalog: PotionSpectrumCatalog = null
@export var unlock_state: PotionSpectrumUnlockState = null
@export var is_pulldown_mode := true

var _is_dragging := false
var _drag_start_y := 0.0
var _panel_start_y := 0.0
var _is_open := false
var _slide_tween: Tween
var _drag_total_offset := 0.0


const DEFAULT_CATALOG_PATH := "res://night/ui/spectrum_codex/resources/default_potion_spectrum_catalog.tres"
const DEFAULT_UNLOCK_STATE_PATH := "res://night/ui/spectrum_codex/resources/default_potion_spectrum_unlock_state.tres"

enum ViewMode {
	VERTICAL,
	MATRIX
}

var current_view_mode: ViewMode = ViewMode.VERTICAL

@onready var mode_label: Label = %ModeLabel
@onready var mode_switch_button: Button = %ModeSwitchButton
@onready var close_button: Button = %CloseButton

@onready var vertical_view: SpectrumVerticalView = %SpectrumVerticalView
@onready var matrix_view: SpectrumMatrixView = %SpectrumMatrixView
@onready var pull_handle: TextureButton = get_node_or_null("PullHandle")

# Detail panel elements
@onready var detail_title: Label = %DetailTitle
@onready var detail_type_badge: Label = %DetailTypeBadge
@onready var detail_status_badge: Label = %DetailStatusBadge
@onready var detail_description: RichTextLabel = %DetailDescription
@onready var detail_extra_vbox: VBoxContainer = %DetailExtraVBox
@onready var detail_recipes_title: Label = %DetailRecipesTitle
@onready var detail_recipes_list: VBoxContainer = %DetailRecipesList


func _ready() -> void:
	if catalog == null and ResourceLoader.exists(DEFAULT_CATALOG_PATH):
		catalog = load(DEFAULT_CATALOG_PATH) as PotionSpectrumCatalog
	if unlock_state == null and ResourceLoader.exists(DEFAULT_UNLOCK_STATE_PATH):
		unlock_state = load(DEFAULT_UNLOCK_STATE_PATH) as PotionSpectrumUnlockState

	if unlock_state != null:
		unlock_state.state_changed.connect(refresh_view)

	_setup_signals()
	refresh_view()
	_update_view_mode_ui()
	_show_default_detail()

	if is_pulldown_mode:
		if pull_handle:
			pull_handle.gui_input.connect(_on_handle_gui_input)
		resized.connect(_on_resized)
		call_deferred("_on_resized")
		_is_open = false
	else:
		if pull_handle:
			pull_handle.visible = false


func _setup_signals() -> void:
	if mode_switch_button:
		mode_switch_button.pressed.connect(_on_mode_switch_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	if vertical_view:
		vertical_view.band_selected.connect(_on_band_selected)
		vertical_view.function_selected.connect(_on_function_selected)
		vertical_view.recipe_selected.connect(_on_recipe_selected)

	if matrix_view:
		matrix_view.matrix_cell_selected.connect(_on_matrix_cell_selected)


# Public API
func set_catalog(new_catalog: PotionSpectrumCatalog) -> void:
	catalog = new_catalog
	refresh_view()


func set_unlock_state(new_unlock_state: PotionSpectrumUnlockState) -> void:
	if unlock_state != null and unlock_state.state_changed.is_connected(refresh_view):
		unlock_state.state_changed.disconnect(refresh_view)
	unlock_state = new_unlock_state
	if unlock_state != null:
		unlock_state.state_changed.connect(refresh_view)
	refresh_view()


func unlock_recipe(recipe_id: StringName) -> void:
	if unlock_state != null:
		unlock_state.unlock_recipe(recipe_id)
		refresh_view()


func unlock_function(function_id: StringName) -> void:
	if unlock_state != null:
		unlock_state.unlock_function(function_id)
		refresh_view()


func set_view_mode(mode: StringName) -> void:
	var target_mode := ViewMode.VERTICAL
	if mode == &"matrix":
		target_mode = ViewMode.MATRIX
	current_view_mode = target_mode
	if is_node_ready():
		_update_view_mode_ui()
	view_mode_changed.emit(mode)


func refresh_view() -> void:
	if vertical_view:
		vertical_view.setup(catalog, unlock_state)
	if matrix_view:
		matrix_view.setup(catalog, unlock_state)


func focus_recipe(recipe_id: StringName) -> void:
	if current_view_mode == ViewMode.VERTICAL:
		if vertical_view:
			vertical_view.focus_recipe(recipe_id)
	else:
		# In matrix view, locate recipe coordinates
		if catalog:
			var recipe := catalog.get_recipe(recipe_id)
			if recipe and matrix_view:
				matrix_view.select_cell(recipe.matrix_row, recipe.matrix_col)

	# Trigger recipe detail inspection
	if catalog:
		var recipe := catalog.get_recipe(recipe_id)
		if recipe:
			_on_recipe_selected(recipe)


func focus_function(func_id: StringName) -> void:
	if current_view_mode == ViewMode.VERTICAL:
		if vertical_view:
			vertical_view.focus_function(func_id)
	else:
		if catalog:
			var func_def := catalog.get_function(func_id)
			if func_def and matrix_view:
				matrix_view.select_cell(func_def.matrix_row, func_def.matrix_col)

	if catalog:
		var func_def := catalog.get_function(func_id)
		if func_def:
			_on_function_selected(func_def)


func _on_mode_switch_pressed() -> void:
	if current_view_mode == ViewMode.VERTICAL:
		set_view_mode(&"matrix")
	else:
		set_view_mode(&"vertical")


func _update_view_mode_ui() -> void:
	match current_view_mode:
		ViewMode.VERTICAL:
			if mode_label:
				mode_label.text = "当前模式: 光谱视图"
			if mode_switch_button:
				mode_switch_button.text = "切换为交叉表"
			if vertical_view:
				vertical_view.visible = true
			if matrix_view:
				matrix_view.visible = false
		ViewMode.MATRIX:
			if mode_label:
				mode_label.text = "当前模式: 交叉表视图"
			if mode_switch_button:
				mode_switch_button.text = "切换为光谱图"
			if vertical_view:
				vertical_view.visible = false
			if matrix_view:
				matrix_view.visible = true


func _on_close_pressed() -> void:
	if is_pulldown_mode:
		slide_closed()
	request_close.emit()


# Details panel presentations
func _show_default_detail() -> void:
	if detail_title:
		detail_title.text = "药水光谱图鉴"
	if detail_type_badge:
		detail_type_badge.text = "图鉴总览"
	if detail_status_badge:
		detail_status_badge.text = "就绪"
		detail_status_badge.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	if detail_description:
		detail_description.text = "请点击左侧色谱区间、功能节点或特殊药方，查看详细解析与炼制线索。"
	_clear_extra_details()


func _clear_extra_details() -> void:
	if detail_extra_vbox:
		for child in detail_extra_vbox.get_children():
			child.queue_free()
	if detail_recipes_title:
		detail_recipes_title.visible = false
	if detail_recipes_list:
		for child in detail_recipes_list.get_children():
			child.queue_free()


func _on_band_selected(band: PotionSpectrumBand) -> void:
	if band == null:
		return
	_clear_extra_details()

	if detail_title:
		detail_title.text = band.display_name
		detail_title.add_theme_color_override("font_color", band.color.darkened(0.15))
	if detail_type_badge:
		detail_type_badge.text = "颜色区间"
	if detail_status_badge:
		detail_status_badge.text = "波段激活"
		detail_status_badge.add_theme_color_override("font_color", band.color)
	if detail_description:
		detail_description.text = band.description

	_add_detail_row("主功能", band.primary_effect_name)
	_add_detail_row("波段范围", "%.2f ~ %.2f" % [band.spectrum_min, band.spectrum_max])

	# Show child functions summary
	if catalog != null:
		var funcs: Array[PotionFunctionDefinition] = catalog.get_functions_for_band(band.id)
		if not funcs.is_empty():
			_show_related_functions_list(funcs)


func _on_function_selected(func_def: PotionFunctionDefinition) -> void:
	if func_def == null:
		return
	_clear_extra_details()
	function_selected.emit(func_def.id)

	var is_unlocked: bool = unlock_state.is_function_unlocked(func_def.id) if unlock_state else false

	if detail_title:
		detail_title.text = func_def.display_name if is_unlocked else "未知功能分支"
		detail_title.remove_theme_color_override("font_color")
	if detail_type_badge:
		detail_type_badge.text = "功能分支"
	if detail_status_badge:
		detail_status_badge.text = "已发现" if is_unlocked else "未解锁"
		detail_status_badge.add_theme_color_override("font_color", Color(0.22, 0.55, 0.25) if is_unlocked else Color(0.72, 0.28, 0.2))
	if detail_description:
		detail_description.text = func_def.description if is_unlocked else "该功能分支尚未在炼药中萃取合成。请尝试对应颜色的草药组合。"

	if is_unlocked:
		_add_detail_row("主标签", String(func_def.primary_tag))
		_add_detail_row("副标签", String(func_def.secondary_tag))
		_add_detail_row("光谱定位", "%.2f" % func_def.spectrum_position)

	# Show related recipes
	if catalog != null:
		var recipes: Array[PotionRecipeDefinition] = catalog.get_recipes_for_function(func_def.id)
		if not recipes.is_empty():
			_show_related_recipes_list(recipes)


func _on_recipe_selected(recipe: PotionRecipeDefinition) -> void:
	if recipe == null:
		return
	_clear_extra_details()
	recipe_selected.emit(recipe.id)

	var is_unlocked: bool = unlock_state.is_recipe_unlocked(recipe.id) if unlock_state else false

	if detail_title:
		detail_title.text = recipe.display_name if is_unlocked else "未知特殊药方"
		detail_title.remove_theme_color_override("font_color")
	if detail_type_badge:
		detail_type_badge.text = "特殊药方" if recipe.is_special else "标准药方"
	if detail_status_badge:
		detail_status_badge.text = "已掌握" if is_unlocked else "未发现"
		detail_status_badge.add_theme_color_override("font_color", Color(0.72, 0.22, 0.12) if is_unlocked else Color(0.65, 0.35, 0.2))
	if detail_description:
		detail_description.text = recipe.description if is_unlocked else "该药方尚未被掌握。通过特定火候与草药配方进行炼制以解锁。"

	if is_unlocked:
		_add_detail_row("主功能", String(recipe.primary_tag))
		_add_detail_row("副功能", String(recipe.secondary_tag))
		_add_detail_row("矩阵坐标", "(%d, %d)" % [recipe.matrix_row, recipe.matrix_col])
		_add_detail_row("配方特性", "★ 稀有秘药" if recipe.is_special else "标准配方")
	else:
		_add_detail_row("解锁线索", recipe.unlock_hint if not recipe.unlock_hint.is_empty() else "未知")


func _on_matrix_cell_selected(row: int, col: int, recipes: Array[PotionRecipeDefinition]) -> void:
	_clear_extra_details()

	var row_name: String = catalog.matrix_row_labels[row] if (catalog and row < catalog.matrix_row_labels.size()) else "行%d" % row
	var col_name: String = catalog.matrix_col_labels[col] if (catalog and col < catalog.matrix_col_labels.size()) else "列%d" % col

	if detail_title:
		detail_title.text = "%s × %s" % [row_name, col_name]
		detail_title.remove_theme_color_override("font_color")
	if detail_type_badge:
		detail_type_badge.text = "交叉矩阵组合"

	var unlocked_count: int = 0
	for r in recipes:
		if unlock_state and unlock_state.is_recipe_unlocked(r.id):
			unlocked_count += 1

	if detail_status_badge:
		if recipes.is_empty():
			detail_status_badge.text = "无配方"
			detail_status_badge.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		elif unlocked_count == recipes.size():
			detail_status_badge.text = "全部掌握 (%d/%d)" % [unlocked_count, recipes.size()]
			detail_status_badge.add_theme_color_override("font_color", Color(0.72, 0.22, 0.12))
		elif unlocked_count > 0:
			detail_status_badge.text = "部分掌握 (%d/%d)" % [unlocked_count, recipes.size()]
			detail_status_badge.add_theme_color_override("font_color", Color(0.2, 0.45, 0.65))
		else:
			detail_status_badge.text = "未解锁 (0/%d)" % recipes.size()
			detail_status_badge.add_theme_color_override("font_color", Color(0.65, 0.35, 0.2))

	if detail_description:
		if recipes.is_empty():
			detail_description.text = "该功能交汇点暂未记录任何药方。"
		else:
			detail_description.text = "此交汇点共包含 %d 个药方。已掌握 %d 个。" % [recipes.size(), unlocked_count]

	if not recipes.is_empty():
		_show_related_recipes_list(recipes)


func _add_detail_row(label_text: String, value_text: String) -> void:
	if detail_extra_vbox == null:
		return
	var hbox := HBoxContainer.new()
	var l_lbl := Label.new()
	l_lbl.text = label_text + ":"
	l_lbl.custom_minimum_size = Vector2(70, 0)
	l_lbl.add_theme_color_override("font_color", Color(0.55, 0.42, 0.28, 1.0))
	l_lbl.add_theme_font_size_override("font_size", 12)

	var v_lbl := Label.new()
	v_lbl.text = value_text
	v_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	v_lbl.add_theme_color_override("font_color", Color(0.24, 0.16, 0.08, 1.0))
	v_lbl.add_theme_font_size_override("font_size", 12)
	v_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	hbox.add_child(l_lbl)
	hbox.add_child(v_lbl)
	detail_extra_vbox.add_child(hbox)


func _show_related_functions_list(funcs: Array[PotionFunctionDefinition]) -> void:
	if detail_recipes_title:
		detail_recipes_title.text = "包含功能分支:"
		detail_recipes_title.visible = true
	if detail_recipes_list:
		for f in funcs:
			var btn := Button.new()
			var is_u: bool = unlock_state.is_function_unlocked(f.id) if unlock_state else false
			btn.text = ("◈ " + f.display_name) if is_u else "🔒 未知功能分支"
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.pressed.connect(func() -> void:
				_on_function_selected(f)
			)
			detail_recipes_list.add_child(btn)


func _show_related_recipes_list(recipes: Array[PotionRecipeDefinition]) -> void:
	if detail_recipes_title:
		detail_recipes_title.text = "相关药方:"
		detail_recipes_title.visible = true
	if detail_recipes_list:
		for r in recipes:
			var btn := Button.new()
			var is_u: bool = unlock_state.is_recipe_unlocked(r.id) if unlock_state else false
			var prefix := "★ " if (r.is_special and is_u) else "• "
			btn.text = (prefix + r.display_name) if is_u else "🔒 ？？？"
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.pressed.connect(func() -> void:
				_on_recipe_selected(r)
			)
			detail_recipes_list.add_child(btn)


func _on_resized() -> void:
	if not is_pulldown_mode:
		return
	var limit: float = size.y if size.y > 0.0 else 720.0
	if not _is_open and not _is_dragging:
		_set_y_pos(-limit)
		var backdrop_node := get_node_or_null("Backdrop")
		var margin_node := get_node_or_null("Margin")
		if backdrop_node: backdrop_node.visible = false
		if margin_node: margin_node.visible = false


func _set_y_pos(y: float) -> void:
	position.y = y


func _on_handle_gui_input(event: InputEvent) -> void:
	if not is_pulldown_mode:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging = true
				_drag_start_y = mb.global_position.y
				_panel_start_y = position.y
				_drag_total_offset = 0.0
				if _slide_tween:
					_slide_tween.kill()
				# Make sure background and margins are visible when starting drag
				var backdrop_node := get_node_or_null("Backdrop")
				var margin_node := get_node_or_null("Margin")
				if backdrop_node: backdrop_node.visible = true
				if margin_node: margin_node.visible = true
			else:
				if _is_dragging:
					_is_dragging = false
					var drag_dist: float = mb.global_position.y - _drag_start_y
					var limit: float = size.y if size.y > 0.0 else 720.0
					var threshold: float = limit * 0.20

					if absf(drag_dist) < 5.0:
						_toggle_panel()
					else:
						var current_y: float = position.y
						if _is_open:
							if current_y < -threshold:
								slide_closed()
							else:
								slide_open()
						else:
							if current_y > -limit + threshold:
								slide_open()
							else:
								slide_closed()
			accept_event()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_dragging:
			var mouse_y: float = mm.global_position.y
			var delta: float = mouse_y - _drag_start_y
			_drag_total_offset = delta
			var limit: float = size.y if size.y > 0.0 else 720.0
			var new_y: float = clampf(_panel_start_y + delta, -limit, 0.0)
			_set_y_pos(new_y)
			accept_event()


func _on_handle_pressed() -> void:
	pass # Toggling is handled inside gui_input to prevent conflict with dragging


func _toggle_panel() -> void:
	if _is_open:
		slide_closed()
	else:
		slide_open()


func slide_open() -> void:
	_is_open = true
	var backdrop_node := get_node_or_null("Backdrop")
	var margin_node := get_node_or_null("Margin")
	if backdrop_node: backdrop_node.visible = true
	if margin_node: margin_node.visible = true

	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(self, "position:y", 0.0, 0.4)


func slide_closed() -> void:
	_is_open = false
	var limit: float = size.y if size.y > 0.0 else 720.0

	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(self, "position:y", -limit, 0.4)
	_slide_tween.tween_callback(func():
		if not _is_open:
			var backdrop_node := get_node_or_null("Backdrop")
			var margin_node := get_node_or_null("Margin")
			if backdrop_node: backdrop_node.visible = false
			if margin_node: margin_node.visible = false
	)


func _unhandled_input(event: InputEvent) -> void:
	if is_pulldown_mode and _is_open:
		if event.is_action_pressed("ui_cancel"):
			slide_closed()
			get_viewport().set_input_as_handled()
