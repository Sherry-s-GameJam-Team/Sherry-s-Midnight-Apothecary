extends CanvasLayer
class_name OperationReminder

@export var pixel_font: Font = preload("res://game/assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf")
@export var font_size: int = 18
@export var top_margin: float = 16.0
@export var screen_margin: float = 24.0
@export var min_width: float = 260.0
@export var max_width: float = 860.0
@export var horizontal_padding: int = 22
@export var vertical_padding: int = 10
@export var corner_radius: int = 12
@export var panel_color: Color = Color(0.0, 0.0, 0.0, 0.68)
@export var type_speed: float = 34.0
@export var default_hold_time: float = 1.7
@export var fade_duration: float = 0.16
@export var auto_play_on_ready: bool = false
@export_multiline var auto_play_text: String = "按下 E 调查月光药柜"

@onready var top_anchor: Control = $TopAnchor
@onready var panel: PanelContainer = $TopAnchor/Panel
@onready var margin: MarginContainer = $TopAnchor/Panel/Margin
@onready var text_label: RichTextLabel = $TopAnchor/Panel/Margin/Text

var _message_queue: Array[Dictionary] = []
var _is_showing: bool = false
var _is_persistent: bool = false
var _active_tween: Tween = null


func _ready() -> void:
	layer = max(layer, 200)
	visible = false
	_configure_nodes()
	get_viewport().size_changed.connect(_align_panel)
	if auto_play_on_ready and not auto_play_text.is_empty():
		call_deferred("show_reminder", auto_play_text)


func show_reminder(message: String, hold_time: float = -1.0) -> void:
	if message.strip_edges().is_empty():
		return

	_is_persistent = false
	_message_queue.append({
		"message": message,
		"hold_time": hold_time,
	})

	if not _is_showing:
		_play_next()


func clear_queue() -> void:
	_message_queue.clear()


func hide_now() -> void:
	_message_queue.clear()
	_is_showing = false
	_is_persistent = false
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null
	visible = false


func show_persistent_reminder(message: String) -> void:
	if message.strip_edges().is_empty():
		return

	_message_queue.clear()
	_is_showing = true
	_is_persistent = true
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null

	visible = true
	text_label.visible_characters = -1
	text_label.text = "[center][wave amp=4 freq=6 connected=0]%s[/wave][/center]" % _escape_bbcode(message)
	_resize_for_message(message)
	await get_tree().process_frame
	_align_panel()

	if panel.modulate.a >= 0.99:
		panel.modulate.a = 1.0
		return

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(panel, "modulate:a", 1.0, fade_duration)
	await _active_tween.finished
	_active_tween = null


func hide_persistent_reminder() -> void:
	if not _is_persistent:
		hide_now()
		return

	_message_queue.clear()
	_is_showing = false
	_is_persistent = false
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.tween_property(panel, "modulate:a", 0.0, fade_duration)
	await _active_tween.finished
	visible = false
	_active_tween = null


func _configure_nodes() -> void:
	top_anchor.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_anchor.offset_left = 0.0
	top_anchor.offset_top = 0.0
	top_anchor.offset_right = 0.0
	top_anchor.offset_bottom = 112.0
	top_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	panel.add_theme_stylebox_override("panel", _make_panel_style())

	margin.add_theme_constant_override("margin_left", horizontal_padding)
	margin.add_theme_constant_override("margin_right", horizontal_padding)
	margin.add_theme_constant_override("margin_top", vertical_padding)
	margin.add_theme_constant_override("margin_bottom", vertical_padding)

	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_override("normal_font", pixel_font)
	text_label.add_theme_font_size_override("normal_font_size", font_size)
	text_label.add_theme_color_override("default_color", Color(0.96, 0.93, 0.84, 1.0))


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = panel_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style


func _play_next() -> void:
	if _is_persistent:
		return
	if _message_queue.is_empty():
		_is_showing = false
		return

	_is_showing = true
	var item: Dictionary = _message_queue.pop_front() as Dictionary
	var message: String = String(item["message"])
	var hold_time: float = float(item["hold_time"])
	await _show_message(message, hold_time)
	_play_next()


func _show_message(message: String, hold_time: float) -> void:
	if not is_inside_tree():
		return

	visible = true
	panel.modulate.a = 0.0
	text_label.visible_characters = 0
	text_label.text = "[center][wave amp=4 freq=6 connected=0]%s[/wave][/center]" % _escape_bbcode(message)
	_resize_for_message(message)
	await get_tree().process_frame
	_align_panel()

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(panel, "modulate:a", 1.0, fade_duration)
	await _active_tween.finished

	var total_characters: int = maxi(1, text_label.get_total_character_count())
	var type_duration: float = float(total_characters) / maxf(1.0, type_speed)
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_LINEAR)
	_active_tween.tween_method(_set_visible_characters, 0, total_characters, type_duration)
	await _active_tween.finished

	var resolved_hold_time: float = default_hold_time if hold_time < 0.0 else hold_time
	await get_tree().create_timer(maxf(0.0, resolved_hold_time)).timeout
	if _is_persistent:
		return

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.tween_property(panel, "modulate:a", 0.0, fade_duration)
	await _active_tween.finished
	visible = false
	_active_tween = null


func _set_visible_characters(value: float) -> void:
	text_label.visible_characters = roundi(value)


func _resize_for_message(message: String) -> void:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var panel_max_width: float = minf(max_width, viewport_width - screen_margin * 2.0)
	var content_max_width: float = maxf(120.0, panel_max_width - float(horizontal_padding * 2))
	var content_min_width: float = maxf(120.0, min_width - float(horizontal_padding * 2))
	var measured_width: float = pixel_font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + 8.0
	var content_width: float = clampf(measured_width, content_min_width, content_max_width)

	text_label.custom_minimum_size = Vector2(content_width, 30.0)
	panel.custom_minimum_size.x = content_width + float(horizontal_padding * 2)


func _align_panel() -> void:
	if panel == null:
		return

	var viewport_width: float = get_viewport().get_visible_rect().size.x
	panel.position = Vector2(
		roundf((viewport_width - panel.size.x) * 0.5),
		roundf(top_margin)
	)


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")
