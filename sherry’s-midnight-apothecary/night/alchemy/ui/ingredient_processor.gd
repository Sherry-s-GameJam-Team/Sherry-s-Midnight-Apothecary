class_name IngredientProcessor
extends PanelContainer

signal herb_dropped(ingredient_id: StringName)
signal selection_changed(start_x: float, end_x: float)
signal tool_requested(tool_id: StringName)

@export var art_mode := false

var current: ProcessedIngredient
var _syncing := false
var _title_label: Label
var _name_label: Label
var _start_slider: HSlider
var _end_slider: HSlider
var _stats_label: Label
var _output: PanelContainer


func _ready() -> void:
	var column := VBoxContainer.new()
	_title_label = Label.new()
	_title_label.text = "材料处理台（把药材拖到这里）"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label = Label.new()
	_start_slider = HSlider.new()
	_end_slider = HSlider.new()
	for slider: HSlider in [_start_slider, _end_slider]:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.001
		slider.value_changed.connect(_on_selection_changed)
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tool_row := HBoxContainer.new()
	for tool_data: Array in [["研磨", &"grind"], ["蒸馏", &"distill"], ["加水", &"dilute"]]:
		var button := Button.new()
		button.text = tool_data[0]
		button.pressed.connect(func() -> void: tool_requested.emit(tool_data[1]))
		tool_row.add_child(button)
	_output = _ProcessedOutput.new()
	_output.custom_minimum_size = Vector2(0, 44)
	_output.set("processor", self)
	column.add_child(_title_label)
	column.add_child(_name_label)
	column.add_child(_start_slider)
	column.add_child(_end_slider)
	column.add_child(tool_row)
	column.add_child(_stats_label)
	column.add_child(_output)
	add_child(column)
	if art_mode:
		for label: Label in [_title_label, _name_label, _stats_label]:
			label.add_theme_color_override("font_color", Color("#3b2514"))
			label.add_theme_color_override("font_shadow_color", Color(0.88, 0.78, 0.59, 0.65))
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
	show_ingredient(null)


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return current == null and data is Dictionary and data.get("kind") == &"herb"


func _drop_data(_position: Vector2, data: Variant) -> void:
	herb_dropped.emit(StringName(str(data.get("ingredient_id", ""))))


func show_ingredient(value: ProcessedIngredient) -> void:
	current = value
	if not is_node_ready():
		return
	_syncing = true
	if current == null:
		_title_label.text = "将药材拖到砧板开始处理"
		_name_label.text = ""
		_stats_label.text = ""
		_start_slider.editable = false
		_end_slider.editable = false
	else:
		_title_label.text = "材料处理台"
		_name_label.text = "%s　原始范围 %.2f–%.2f" % [
			current.source_data.display_name,
			current.source_data.spectrum_start,
			current.source_data.spectrum_end,
		]
		_start_slider.editable = true
		_end_slider.editable = true
		_start_slider.min_value = current.source_data.spectrum_start
		_start_slider.max_value = current.source_data.spectrum_end
		_end_slider.min_value = current.source_data.spectrum_start
		_end_slider.max_value = current.source_data.spectrum_end
		_start_slider.value = current.selected_start
		_end_slider.value = current.selected_end
		_stats_label.text = "选取 %.3f–%.3f　色值 %.3f\n浓度 %.2f　品质 %.2f　提取率 %.0f%%" % [
			current.selected_start,
			current.selected_end,
			current.spectrum_x,
			current.concentration,
			current.quality,
			current.extraction_ratio * 100.0,
		]
		_output.queue_redraw()
	_start_slider.visible = current != null
	_end_slider.visible = current != null
	_stats_label.visible = current != null
	_output.visible = current != null
	for child: Node in _start_slider.get_parent().get_children():
		if child is HBoxContainer:
			child.visible = current != null
	_syncing = false


func _on_selection_changed(_value: float) -> void:
	if not _syncing and current != null:
		selection_changed.emit(_start_slider.value, _end_slider.value)


class _ProcessedOutput:
	extends PanelContainer

	var processor: IngredientProcessor

	func _init() -> void:
		var label := Label.new()
		label.text = "处理完成输出（拖入炼药锅）"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)

	func _get_drag_data(_position: Vector2) -> Variant:
		if processor == null or processor.current == null:
			return null
		var preview := Label.new()
		preview.text = processor.current.source_data.display_name
		set_drag_preview(preview)
		return {"kind": &"processed_ingredient", "ingredient": processor.current}
