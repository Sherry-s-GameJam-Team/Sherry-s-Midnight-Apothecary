class_name ApothecaryDialogueBalloon
extends CanvasLayer

signal load_requested
signal settings_requested

@export var dialogue_resource: DialogueResource
@export var start_from_title: String = "start"
@export var auto_start: bool = false
@export var will_block_other_input: bool = true
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"
@export_range(0.0, 2.0, 0.01) var enter_duration := 0.42
@export_range(0.0, 2.0, 0.01) var exit_duration := 0.32
@export var transition_offset := 72.0

@onready var balloon: Control = %Balloon
@onready var frame_dock: AspectRatioContainer = %FrameDock
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var progress: Control = %Progress
@onready var progress_mark: DialogueProgressIndicator = %AnimatedMark
@onready var auto_button: TextureButton = %AutoButton
@onready var history_panel: PanelContainer = %HistoryPanel
@onready var history_label: RichTextLabel = %HistoryLabel
@onready var status_label: Label = %StatusLabel

var temporary_game_states: Array = []
var is_waiting_for_input := false
var auto_mode := false
var will_hide_balloon := false
var locals: Dictionary = {}
var dialogue_line: DialogueLine:
	set(value):
		dialogue_line = value
		if value:
			apply_dialogue_line()
		else:
			_close_balloon()
	get:
		return dialogue_line

var _history: Array[String] = []
var _locale := TranslationServer.get_locale()
var _mutation_cooldown := Timer.new()
var _status_tween: Tween
var _transition_tween: Tween
var _has_entered := false
var _is_transitioning := false
var _is_closing := false


func _ready() -> void:
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action
	_mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(_mutation_cooldown)
	if auto_start:
		assert(is_instance_valid(dialogue_resource), DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_line):
		var show_static_frame := dialogue_label.is_typing
		var play_progress_animation := (
			not show_static_frame
			and dialogue_line.responses.is_empty()
			and is_waiting_for_input
		)
		progress.visible = show_static_frame or play_progress_animation
		progress_mark.set_playing(play_progress_animation)
	else:
		progress.hide()
		progress_mark.set_playing(false)


func _unhandled_input(_event: InputEvent) -> void:
	if will_block_other_input and balloon.visible:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_TRANSLATION_CHANGED
		and _locale != TranslationServer.get_locale()
		and is_instance_valid(dialogue_label)
		and is_instance_valid(dialogue_line)
	):
		_locale = TranslationServer.get_locale()
		var visible_ratio := dialogue_label.visible_ratio
		dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1.0:
			dialogue_label.skip_typing()


func start(
	with_dialogue_resource: DialogueResource = null,
	title: String = "",
	extra_game_states: Array = []
) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	_history.clear()
	history_panel.hide()
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	show()


func apply_dialogue_line() -> void:
	_mutation_cooldown.stop()
	progress.hide()
	progress_mark.set_playing(false)
	is_waiting_for_input = false

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")
	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line
	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses
	_append_history(dialogue_line)

	will_hide_balloon = false
	var current_line_id := dialogue_line.id
	if not _has_entered:
		await _play_enter_transition()
		if not is_instance_valid(dialogue_line) or dialogue_line.id != current_line_id:
			return
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()
	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing
	if not is_instance_valid(dialogue_line) or dialogue_line.id != current_line_id:
		return

	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var wait_time := dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(wait_time).timeout
		next(dialogue_line.next_id)
	elif auto_mode:
		await get_tree().create_timer(0.75).timeout
		if is_instance_valid(dialogue_line) and dialogue_line.id == current_line_id:
			next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


func next(next_id: String) -> void:
	if _is_transitioning or _is_closing:
		return
	history_panel.hide()
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


func is_transitioning() -> bool:
	return _is_transitioning


func _play_enter_transition() -> void:
	_kill_transition_tween()
	_is_transitioning = true
	balloon.show()
	await get_tree().process_frame
	var rest_position := frame_dock.position
	var travel_distance := maxf(frame_dock.size.y, 1.0) + transition_offset
	frame_dock.position = rest_position + Vector2(0.0, travel_distance)
	frame_dock.modulate.a = 0.0
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(
		frame_dock,
		"position",
		rest_position,
		enter_duration
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(
		frame_dock,
		"modulate:a",
		1.0,
		enter_duration * 0.72
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _transition_tween.finished
	_transition_tween = null
	frame_dock.position = rest_position
	frame_dock.modulate.a = 1.0
	_has_entered = true
	_is_transitioning = false


func _play_exit_transition() -> void:
	_kill_transition_tween()
	_is_transitioning = true
	var rest_position := frame_dock.position
	var travel_distance := maxf(frame_dock.size.y, 1.0) + transition_offset
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(
		frame_dock,
		"position",
		rest_position + Vector2(0.0, travel_distance),
		exit_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(
		frame_dock,
		"modulate:a",
		0.0,
		exit_duration * 0.8
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _transition_tween.finished
	_transition_tween = null
	_is_transitioning = false
	frame_dock.position = rest_position
	frame_dock.modulate.a = 1.0


func _close_balloon() -> void:
	if _is_closing:
		return
	_is_closing = true
	is_waiting_for_input = false
	progress.hide()
	progress_mark.set_playing(false)
	responses_menu.hide()
	if _has_entered and balloon.visible:
		await _play_exit_transition()
	_has_entered = false
	balloon.hide()
	if owner == null:
		queue_free()
	else:
		hide()
	_is_closing = false


func _kill_transition_tween() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


func _append_history(line: DialogueLine) -> void:
	var speaker := tr(line.character, "dialogue")
	var body := tr(line.text, "dialogue")
	_history.append(("[color=#754319][b]%s[/b][/color]\n%s" % [speaker, body]) if not speaker.is_empty() else body)
	if _history.size() > 30:
		_history.pop_front()


func _on_balloon_gui_input(event: InputEvent) -> void:
	if _is_transitioning or _is_closing:
		return
	if dialogue_label.is_typing:
		var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		if clicked or event.is_action_pressed(skip_action):
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
		return
	if not is_waiting_for_input or dialogue_line.responses.size() > 0:
		return
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		get_viewport().set_input_as_handled()
		next(dialogue_line.next_id)


func _on_fast_pressed() -> void:
	if _is_transitioning or _is_closing:
		return
	if dialogue_label.is_typing:
		dialogue_label.skip_typing()
	elif is_waiting_for_input and is_instance_valid(dialogue_line):
		next(dialogue_line.next_id)


func _on_auto_pressed() -> void:
	if _is_transitioning or _is_closing:
		return
	auto_mode = not auto_mode
	auto_button.modulate = Color(1.12, 0.93, 0.58) if auto_mode else Color.WHITE
	_show_status("自动播放：开启" if auto_mode else "自动播放：关闭")
	if auto_mode and is_waiting_for_input and is_instance_valid(dialogue_line):
		is_waiting_for_input = false
		await get_tree().create_timer(0.35).timeout
		if is_instance_valid(dialogue_line):
			next(dialogue_line.next_id)


func _on_back_pressed() -> void:
	if _is_transitioning or _is_closing:
		return
	history_panel.visible = not history_panel.visible
	if history_panel.visible:
		history_label.text = "\n\n".join(_history)
		history_label.scroll_to_line(maxi(0, history_label.get_line_count() - 1))


func _on_settings_pressed() -> void:
	if _is_transitioning or _is_closing:
		return
	history_panel.hide()
	settings_requested.emit()
	var pause_menu := get_tree().get_first_node_in_group("pause_menu") as PauseMenu
	if is_instance_valid(pause_menu):
		pause_menu.open(PauseMenu.Page.SETTINGS)
	else:
		_show_status("未找到暂停菜单")


func _on_load_pressed() -> void:
	if _is_transitioning or _is_closing:
		return
	load_requested.emit()
	var current_scene := get_tree().current_scene
	if is_instance_valid(current_scene) and current_scene.has_method("load_game"):
		current_scene.call("load_game")
		_show_status("已请求读取存档")
	else:
		_show_status("测试场景：已发出读取存档信号")


func _show_status(message: String) -> void:
	status_label.text = message
	status_label.modulate.a = 1.0
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(1.1)
	_status_tween.tween_property(status_label, "modulate:a", 0.0, 0.35)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	if _is_transitioning or _is_closing:
		return
	next(response.next_id)


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		_mutation_cooldown.start(0.1)
