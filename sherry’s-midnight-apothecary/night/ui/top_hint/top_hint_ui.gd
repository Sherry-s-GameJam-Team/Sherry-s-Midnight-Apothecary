class_name TopHintUI
extends CanvasLayer

signal hint_started(hint_id: String)
signal hint_finished(hint_id: String)
signal image_opened(hint_id: String)
signal image_closed(hint_id: String)

@export_group("Typewriter")
@export_range(0.005, 0.2, 0.005) var seconds_per_character := 0.028
@export var punctuation_pause_multiplier := 4.0
@export_group("Motion")
@export_range(0.05, 1.0, 0.01) var reveal_duration := 0.22
@export_range(120.0, 520.0, 1.0) var image_reveal_height := 300.0
@export_group("Behavior")
@export var default_auto_hide_seconds := 4.0
@export var image_once_by_default := true
@export var expand_action := &"hint_expand"
@export var skip_action := &"hint_skip"
@export_range(320.0, 1400.0, 1.0) var max_width := 860.0
@export_range(8.0, 120.0, 1.0) var horizontal_safe_margin := 24.0

var player_data: PlayerData
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _seen_image_ids: Dictionary = {}
var _typewriter_tween: Tween
var _reveal_tween: Tween
var _is_typing := false
var _image_expanded := false
var _current_has_image := false

@onready var _top_dock: VBoxContainer = %TopDock
@onready var _hint_label: RichTextLabel = %HintLabel
@onready var _expand_row: HBoxContainer = %ExpandRow
@onready var _expand_key: Label = %ExpandKey
@onready var _expand_text: Label = %ExpandText
@onready var _image_reveal: Control = %ImageReveal
@onready var _image_texture: TextureRect = %ImageTexture
@onready var _image_caption: Label = %ImageCaption
@onready var _auto_hide_timer: Timer = %AutoHideTimer


func _ready() -> void:
	_ensure_default_input_action(expand_action, KEY_E)
	_ensure_default_input_action(skip_action, KEY_SPACE)
	_expand_key.text = _format_action_key(expand_action)
	_top_dock.hide()
	_image_reveal.hide()
	get_viewport().size_changed.connect(_update_safe_width)
	_update_safe_width()


func bind_player_data(shared_player_data: PlayerData) -> void:
	player_data = shared_player_data


func push_hint(text: String, image: Texture2D = null, hint_id: String = "", image_caption_text: String = "", image_once: bool = true, auto_hide_seconds: float = -1.0) -> void:
	var resolved_id := hint_id if not hint_id.is_empty() else text
	_queue.append({"text": text, "image": image, "id": resolved_id, "caption": image_caption_text, "image_once": image_once, "auto_hide": auto_hide_seconds})
	if _current.is_empty():
		_play_next()


func push_text(text: String, hint_id: String = "", auto_hide_seconds: float = -1.0) -> void:
	push_hint(text, null, hint_id, "", image_once_by_default, auto_hide_seconds)


func push_image_hint(text: String, image: Texture2D, hint_id: String, caption: String = "", image_once: bool = true, auto_hide_seconds: float = -1.0) -> void:
	push_hint(text, image, hint_id, caption, image_once, auto_hide_seconds)


func dismiss_current() -> void:
	if _current.is_empty():
		return
	_auto_hide_timer.stop()
	if _image_expanded:
		_set_image_expanded(false, true)
		await get_tree().create_timer(reveal_duration).timeout
	var finished_id: String = _current.get("id", "")
	_top_dock.hide()
	_current.clear()
	_current_has_image = false
	hint_finished.emit(finished_id)
	_play_next()


func clear_all() -> void:
	_queue.clear()
	_kill_tweens()
	_auto_hide_timer.stop()
	_image_reveal.custom_minimum_size.y = 0.0
	_image_reveal.hide()
	_top_dock.hide()
	_current.clear()
	_current_has_image = false
	_image_expanded = false


func has_seen_image(hint_id: String) -> bool:
	return bool(player_data.tutorial_flags.get(hint_id, false)) if player_data != null else _seen_image_ids.has(hint_id)


func _input(event: InputEvent) -> void:
	if _current.is_empty():
		return
	if event.is_action_pressed(skip_action) and _is_typing:
		_finish_typewriter_immediately()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(expand_action) and _current_has_image:
		if _is_typing:
			_finish_typewriter_immediately()
		_set_image_expanded(not _image_expanded)
		get_viewport().set_input_as_handled()


func _play_next() -> void:
	if _queue.is_empty():
		return
	_current = _queue.pop_front()
	var id: String = _current.get("id", "")
	var texture: Texture2D = _current.get("image")
	var once: bool = _current.get("image_once", image_once_by_default)
	_current_has_image = texture != null and (not once or not has_seen_image(id))
	_image_expanded = false
	_top_dock.show()
	_image_reveal.hide()
	_image_reveal.custom_minimum_size.y = 0.0
	_image_texture.texture = texture
	_image_caption.text = _current.get("caption", "")
	_image_caption.visible = not _image_caption.text.is_empty()
	_expand_row.visible = _current_has_image
	_expand_key.text = _format_action_key(expand_action)
	_expand_text.text = "展开图示"
	hint_started.emit(id)
	_start_typewriter(String(_current.get("text", "")))


func _start_typewriter(text: String) -> void:
	_kill_typewriter()
	_auto_hide_timer.stop()
	_hint_label.text = text
	_hint_label.visible_characters = 0
	_is_typing = true
	_typewriter_step(text, 0)


func _typewriter_step(text: String, index: int) -> void:
	if not _is_typing:
		return
	if index >= text.length():
		_on_typewriter_finished()
		return
	_hint_label.visible_characters = index + 1
	var delay := seconds_per_character
	if text.substr(index, 1) in ["。", "！", "？", "，", ".", "!", "?", ",", ";", "；", ":", "："]:
		delay *= punctuation_pause_multiplier
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_interval(delay)
	_typewriter_tween.finished.connect(_typewriter_step.bind(text, index + 1), CONNECT_ONE_SHOT)


func _finish_typewriter_immediately() -> void:
	_kill_typewriter()
	_hint_label.visible_characters = -1
	_on_typewriter_finished()


func _on_typewriter_finished() -> void:
	_is_typing = false
	_hint_label.visible_characters = -1
	var auto_hide: float = _current.get("auto_hide", -1.0)
	if auto_hide < 0.0:
		auto_hide = default_auto_hide_seconds
	if auto_hide > 0.0 and not _image_expanded:
		_auto_hide_timer.start(auto_hide)


func _set_image_expanded(expanded: bool, silent := false) -> void:
	if not _current_has_image:
		return
	_auto_hide_timer.stop()
	_image_expanded = expanded
	_kill_reveal()
	_expand_text.text = "收起图示" if expanded else "展开图示"
	_reveal_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	if expanded:
		_image_reveal.show()
		_image_reveal.custom_minimum_size.y = maxf(_image_reveal.custom_minimum_size.y, 0.0)
		_reveal_tween.tween_property(_image_reveal, "custom_minimum_size:y", image_reveal_height, reveal_duration)
		_mark_image_seen(String(_current.get("id", "")))
		if not silent:
			image_opened.emit(String(_current.get("id", "")))
	else:
		_reveal_tween.tween_property(_image_reveal, "custom_minimum_size:y", 0.0, reveal_duration)
		_reveal_tween.finished.connect(_on_image_collapse_finished.bind(silent), CONNECT_ONE_SHOT)


func _on_image_collapse_finished(silent: bool) -> void:
	_image_reveal.hide()
	if not silent:
		image_closed.emit(String(_current.get("id", "")))
	if not _is_typing and not _current.is_empty():
		_on_typewriter_finished()


func _on_expand_row_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _current_has_image:
		if _is_typing:
			_finish_typewriter_immediately()
		_set_image_expanded(not _image_expanded)
		get_viewport().set_input_as_handled()


func _mark_image_seen(hint_id: String) -> void:
	if not _current.get("image_once", image_once_by_default):
		return
	if player_data != null:
		player_data.tutorial_flags[hint_id] = true
	else:
		_seen_image_ids[hint_id] = true


func _update_safe_width() -> void:
	if _top_dock == null:
		return
	var viewport_width := float(get_viewport().get_visible_rect().size.x)
	_top_dock.custom_minimum_size.x = minf(max_width, maxf(320.0, viewport_width - horizontal_safe_margin * 2.0))


func _ensure_default_input_action(action: StringName, physical_key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var key_event := InputEventKey.new()
		key_event.physical_keycode = physical_key
		InputMap.action_add_event(action, key_event)


func _format_action_key(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty() or events[0] is not InputEventKey:
		return "[E]"
	var key_event := events[0] as InputEventKey
	var label := OS.get_keycode_string(key_event.physical_keycode)
	if label.is_empty():
		label = OS.get_keycode_string(key_event.keycode)
	return "[%s]" % label


func _kill_tweens() -> void:
	_kill_typewriter()
	_kill_reveal()


func _kill_typewriter() -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()


func _kill_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()


func _build_ui_legacy() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top_center := CenterContainer.new()
	top_center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_center.offset_top = 18.0
	top_center.offset_bottom = 18.0
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_center)
	_top_dock = VBoxContainer.new()
	_top_dock.add_theme_constant_override("separation", 0)
	_top_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.add_child(_top_dock)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	_top_dock.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_ornament())
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 3)
	row.add_child(center)
	_hint_label = RichTextLabel.new()
	_hint_label.custom_minimum_size.y = 34.0
	_hint_label.fit_content = true
	_hint_label.bbcode_enabled = true
	_hint_label.add_theme_font_size_override("normal_font_size", 20)
	_hint_label.add_theme_color_override("default_color", Color("f2e6c7"))
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_hint_label)
	_expand_row = HBoxContainer.new()
	_expand_row.alignment = BoxContainer.ALIGNMENT_END
	_expand_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_expand_row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_expand_row.add_theme_constant_override("separation", 6)
	_expand_row.gui_input.connect(_on_expand_row_gui_input)
	center.add_child(_expand_row)
	_expand_key = Label.new()
	_expand_key.text = "[E]"
	_expand_key.add_theme_font_size_override("font_size", 15)
	_expand_key.add_theme_color_override("font_color", Color("f2d491"))
	_expand_key.add_theme_stylebox_override("normal", _key_style())
	_expand_row.add_child(_expand_key)
	_expand_text = Label.new()
	_expand_text.add_theme_font_size_override("font_size", 15)
	_expand_text.add_theme_color_override("font_color", Color("c2ad8c"))
	_expand_row.add_child(_expand_text)
	row.add_child(_ornament())
	_image_reveal = Control.new()
	_image_reveal.clip_contents = true
	_image_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_dock.add_child(_image_reveal)
	var image_panel := PanelContainer.new()
	image_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	image_panel.offset_bottom = image_reveal_height
	image_panel.add_theme_stylebox_override("panel", _image_style())
	_image_reveal.add_child(image_panel)
	var image_box := VBoxContainer.new()
	image_box.add_theme_constant_override("separation", 7)
	image_panel.add_child(image_box)
	_image_texture = TextureRect.new()
	_image_texture.custom_minimum_size.y = image_reveal_height - 50.0
	_image_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_box.add_child(_image_texture)
	_image_caption = Label.new()
	_image_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_image_caption.add_theme_font_size_override("font_size", 14)
	_image_caption.add_theme_color_override("font_color", Color("c2ad8c"))
	image_box.add_child(_image_caption)
	_auto_hide_timer = Timer.new()
	_auto_hide_timer.one_shot = true
	_auto_hide_timer.timeout.connect(_on_auto_hide_timer_timeout)
	add_child(_auto_hide_timer)
	_top_dock.hide()
	_image_reveal.hide()


func _ornament() -> TextureRect:
	var ornament := TextureRect.new()
	ornament.custom_minimum_size = Vector2(44, 44)
	ornament.texture = load("res://night/art/ui/ornament.svg") as Texture2D
	ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ornament.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ornament.modulate = Color(0.93, 0.78, 0.48, 0.72)
	return ornament


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b1510f6")
	style.border_color = Color("a87d47")
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 24.0
	style.content_margin_top = 12.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 12.0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 7
	return style


func _image_style() -> StyleBoxFlat:
	var style := _panel_style()
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	return style


func _key_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.73, 0.58, 0.34, 0.2)
	style.border_color = Color(0.82, 0.67, 0.42, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7.0
	style.content_margin_top = 2.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 2.0
	return style


func _on_auto_hide_timer_timeout() -> void:
	dismiss_current()
