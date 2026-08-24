class_name ApothecaryDialogueBalloon
extends CanvasLayer

const DialoguePortraitDatabase := preload("res://night/dialogue/portrait_database.gd")
const DialoguePortraitSlot := preload("res://night/dialogue/dialogue_portrait_slot.gd")

signal load_requested
signal settings_requested
signal dialogue_event(event_name: StringName, payload: Variant)
signal hint_requested(text: String, hint_id: String, auto_hide_seconds: float)
signal persistent_hint_requested(text: String, hint_id: String)
signal hint_hide_requested(hint_id: String)

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
@onready var portrait_layer: Control = _resolve_slot_node("%PortraitLayer", "Balloon/PortraitLayer")
@onready var left_slot: DialoguePortraitSlot = _resolve_slot_node("%LeftSlot", "Balloon/PortraitLayer/LeftSlot") as DialoguePortraitSlot
@onready var center_slot: DialoguePortraitSlot = _resolve_slot_node("%CenterSlot", "Balloon/PortraitLayer/CenterSlot") as DialoguePortraitSlot
@onready var right_slot: DialoguePortraitSlot = _resolve_slot_node("%RightSlot", "Balloon/PortraitLayer/RightSlot") as DialoguePortraitSlot
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var progress: Control = %Progress
@onready var progress_mark: DialogueProgressIndicator = %AnimatedMark
@onready var fast_button: TextureButton = get_node_or_null("%FastButton") as TextureButton
@onready var auto_button: TextureButton = %AutoButton
@onready var back_button: TextureButton = get_node_or_null("%BackButton") as TextureButton
@onready var history_button: TextureButton = get_node_or_null("%HistoryButton") as TextureButton
@onready var history_panel: PanelContainer = %HistoryPanel
@onready var history_close_button: Button = get_node_or_null("%HistoryCloseButton") as Button
@onready var history_label: RichTextLabel = %HistoryLabel
@onready var status_label: Label = %StatusLabel

var temporary_game_states: Array = []
var is_waiting_for_input := false
var auto_mode := false
var fast_mode := false
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
var _history_stack: Array[Dictionary] = []
var _is_rolling_back := false
var _ctrl_fast_active := false
var _locale := TranslationServer.get_locale()
var _mutation_cooldown := Timer.new()
var _status_tween: Tween
var _transition_tween: Tween
var _has_entered := false
var _is_transitioning := false
var _is_closing := false
var _dialogue_targets_locked := false

func _ready() -> void:
	balloon.hide()
	_configure_portrait_ui_layout()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action
	_mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(_mutation_cooldown)
	if auto_start:
		assert(is_instance_valid(dialogue_resource), DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _configure_portrait_ui_layout() -> void:
	if portrait_layer == null:
		return
	portrait_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not portrait_layer.resized.is_connected(_layout_portrait_slots):
		portrait_layer.resized.connect(_layout_portrait_slots)
	call_deferred("_layout_portrait_slots")


func _layout_portrait_slots() -> void:
	if portrait_layer == null or portrait_layer.size.x <= 0.0 or portrait_layer.size.y <= 0.0:
		return
	for slot_name in ["left", "center", "right"]:
		var slot := get_slot(slot_name)
		if slot == null:
			continue
		var normalized_bounds: Rect2 = _get_portrait_slot_bounds(slot_name)
		var pixel_rect := Rect2(
			portrait_layer.size * normalized_bounds.position,
			portrait_layer.size * normalized_bounds.size
		)
		slot.set_dialogue_layout_rect(pixel_rect)


func _get_portrait_slot_bounds(slot_name: String) -> Rect2:
	match slot_name:
		"left":
			return Rect2(0.04, 0.14, 0.38, 0.74)
		"right":
			return Rect2(0.58, 0.14, 0.38, 0.74)
		_:
			return Rect2(0.31, 0.10, 0.38, 0.78)


func _exit_tree() -> void:
	_set_dialogue_targets_locked(false)
	clear_portraits()


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
	_set_dialogue_targets_locked(true)
	temporary_game_states = [self]
	var player_state := _find_player_data()
	if player_state != null and not extra_game_states.has(player_state):
		temporary_game_states.append(player_state)
	temporary_game_states.append_array(extra_game_states)
	is_waiting_for_input = false
	_history.clear()
	history_panel.hide()
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	show()


func _find_player_data() -> PlayerData:
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("get_player_data"):
		return current_scene.call("get_player_data") as PlayerData
	return null


## Dialogue command: do emit_dialogue_event("event_name", optional_payload)
## Gameplay code can subscribe to dialogue_event on this balloon.
func emit_dialogue_event(event_name: String, payload: Variant = null) -> void:
	if event_name.is_empty():
		push_warning("Dialogue event names cannot be empty.")
		return
	dialogue_event.emit(StringName(event_name), payload)


## Dialogue command: do show_hint("text", "optional_id", optional_seconds)
## Pushes an auto-hiding message to the project's existing TopHintUI.
func show_hint(text: String, hint_id: String = "", auto_hide_seconds: float = -1.0) -> void:
	if text.is_empty():
		return
	var resolved_id := hint_id if not hint_id.is_empty() else text
	hint_requested.emit(text, resolved_id, auto_hide_seconds)
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.push_text(text, resolved_id, auto_hide_seconds)


## Dialogue command: do show_persistent_hint("text", "id")
## The hint remains visible until hide_hint is called with the same ID.
func show_persistent_hint(text: String, hint_id: String) -> void:
	if text.is_empty() or hint_id.is_empty():
		push_warning("Persistent dialogue hints require non-empty text and an ID.")
		return
	persistent_hint_requested.emit(text, hint_id)
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(hint_id, text)


## Dialogue command: do hide_hint("id")
func hide_hint(hint_id: String) -> void:
	if hint_id.is_empty():
		return
	hint_hide_requested.emit(hint_id)
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(hint_id)


## Dialogue command: do show_portrait("character", "expression", "slot", "animation")
func show_portrait(
	character_name: String,
	expression: String = "default",
	slot_name: String = "",
	animation: String = "slide_in"
) -> void:
	var target_slot := slot_name
	if target_slot.is_empty():
		target_slot = DialoguePortraitDatabase.get_default_slot_for_character(character_name)
	var slot := get_slot(target_slot)
	if slot != null:
		slot.show_portrait(character_name, expression, animation)
		_update_portrait_focus(character_name)


## Dialogue command: do hide_portrait("slot", "animation")
func hide_portrait(slot_name: String = "center", animation: String = "slide_out") -> void:
	var slot := get_slot(slot_name)
	if slot != null:
		slot.hide_portrait(animation)


## Dialogue command: do clear_portraits()
func clear_portraits() -> void:
	for slot in [left_slot, center_slot, right_slot]:
		if is_instance_valid(slot):
			slot.clear_instant()


## Dialogue command: do set_portrait_focus("slot_or_character")
func set_portrait_focus(slot_or_character: String) -> void:
	_update_portrait_focus(slot_or_character)


func _resolve_slot_node(unique_path: String, fallback_path: String) -> Node:
	var n := get_node_or_null(unique_path)
	if n != null:
		return n
	return get_node_or_null(fallback_path)


func get_slot(slot_name: String) -> DialoguePortraitSlot:
	var norm := DialoguePortraitDatabase.normalize_slot(slot_name)
	match norm:
		"left":
			if left_slot == null:
				left_slot = _resolve_slot_node("%LeftSlot", "Balloon/PortraitLayer/LeftSlot") as DialoguePortraitSlot
			return left_slot
		"right":
			if right_slot == null:
				right_slot = _resolve_slot_node("%RightSlot", "Balloon/PortraitLayer/RightSlot") as DialoguePortraitSlot
			return right_slot
		"center":
			if center_slot == null:
				center_slot = _resolve_slot_node("%CenterSlot", "Balloon/PortraitLayer/CenterSlot") as DialoguePortraitSlot
			return center_slot
	if center_slot == null:
		center_slot = _resolve_slot_node("%CenterSlot", "Balloon/PortraitLayer/CenterSlot") as DialoguePortraitSlot
	return center_slot


func _clean_character_name(raw_char: String) -> String:
	var c := raw_char.strip_edges()
	if c.contains("#"):
		var idx := c.find("#")
		c = c.substr(0, idx).strip_edges()
	if c.contains("(") and c.ends_with(")"):
		var idx := c.find("(")
		c = c.substr(0, idx).strip_edges()
	return c


func _extract_character_tags(raw_char: String) -> Array[String]:
	var extracted: Array[String] = []
	if not raw_char.contains("#"):
		return extracted
	var idx := raw_char.find("#")
	var tag_str := raw_char.substr(idx).strip_edges()
	var parts := tag_str.split("#")
	for part in parts:
		var p := part.strip_edges()
		if not p.is_empty():
			extracted.append(p)
	return extracted


func _process_portrait_syntax(line: DialogueLine) -> void:
	if line == null:
		return

	var clean_speaker := _clean_character_name(line.character)

	# 1. Process tags embedded in character name (e.g. "角色 #left(happy)")
	var char_tags := _extract_character_tags(line.character)
	for tag in char_tags:
		_parse_single_portrait_tag(tag, clean_speaker)

	# 2. Process DialogueManager native line tags
	if line.tags != null and not line.tags.is_empty():
		for tag in line.tags:
			_parse_single_portrait_tag(tag, clean_speaker)

	# 3. Process inline bbcode [portrait=...]
	if line.text.contains("[portrait"):
		_parse_inline_portrait_bbcode(line.text, clean_speaker)

	# 4. Guarantee the two primary speakers stay in their authored sides even
	# when a dialogue resource used legacy inline #left/#right syntax that was
	# normalised by Dialogue Manager before this balloon received the line.
	_ensure_primary_speaker_slot(clean_speaker)

	# 5. Update active speaking focus
	_update_portrait_focus(clean_speaker)


func _parse_single_portrait_tag(tag: String, speaker: String) -> void:
	var t := tag.strip_edges()
	if t.begins_with("#"):
		t = t.substr(1).strip_edges()
	if t.is_empty():
		return

	if t.begins_with("portrait(") and t.ends_with(")"):
		var body := t.substr(9, t.length() - 10).strip_edges()
		if body in ["clear", "reset", "hide_all"]:
			clear_portraits()
			return
		if body.begins_with("hide=") or body.begins_with("hide:"):
			var slot := body.substr(5).strip_edges()
			hide_portrait(slot)
			return

		var char_name := speaker
		var slot_name := ""
		var expr_name := "default"
		var anim_name := "slide_in"
		var parts := body.split(",")
		for part in parts:
			var p := part.strip_edges()
			if p.contains("="):
				var kv := p.split("=", true, 1)
				var k := kv[0].strip_edges().to_lower()
				var v := kv[1].strip_edges()
				match k:
					"slot", "pos", "position":
						slot_name = v
					"expr", "expression", "face", "mood":
						expr_name = v
					"anim", "animation", "motion":
						anim_name = v
					"char", "character", "name", "who":
						char_name = v
			elif not p.is_empty():
				var p_lower := p.to_lower()
				if slot_name.is_empty() and (p_lower in ["left", "right", "center", "l", "r", "c", "mid", "左", "右", "中"]):
					slot_name = p
				elif p_lower in ["slide_in", "fade_in", "bounce", "pop", "shake", "nod"]:
					anim_name = p
				elif expr_name == "default":
					expr_name = p

		if not char_name.is_empty():
			show_portrait(char_name, expr_name, slot_name, anim_name)

	elif t.begins_with("portrait=") or t.begins_with("portrait:"):
		var body := t.substr(9).strip_edges()
		if body in ["clear", "reset"]:
			clear_portraits()
			return
		var tokens := body.split(":")
		var slot_name := ""
		var expr_name := "default"
		var anim_name := "slide_in"
		var char_name := speaker
		if tokens.size() >= 1 and not tokens[0].is_empty():
			slot_name = tokens[0]
		if tokens.size() >= 2 and not tokens[1].is_empty():
			expr_name = tokens[1]
		if tokens.size() >= 3 and not tokens[2].is_empty():
			anim_name = tokens[2]
		if not char_name.is_empty():
			show_portrait(char_name, expr_name, slot_name, anim_name)

	elif t.begins_with("hide_portrait(") and t.ends_with(")"):
		var slot := t.substr(14, t.length() - 15).strip_edges()
		hide_portrait(slot)

	elif t.begins_with("left(") or t.begins_with("right(") or t.begins_with("center("):
		var slot := t.substr(0, t.find("(")).to_lower()
		var body := t.substr(t.find("(") + 1, t.length() - t.find("(") - 2).strip_edges()
		var parts := body.split(",")
		var expr := parts[0].strip_edges() if parts.size() > 0 and not parts[0].strip_edges().is_empty() else "default"
		var anim := parts[1].strip_edges() if parts.size() > 1 and not parts[1].strip_edges().is_empty() else "slide_in"
		if not speaker.is_empty():
			show_portrait(speaker, expr, slot, anim)


func _parse_inline_portrait_bbcode(text: String, speaker: String) -> void:
	var regex := RegEx.new()
	regex.compile("\\[portrait=([^\\]]+)\\]")
	var result := regex.search(text)
	if result != null:
		var content := result.get_string(1).strip_edges()
		if content in ["clear", "reset"]:
			clear_portraits()
			return
		var tokens := content.split(":")
		var char_name := speaker
		var expr_name := "default"
		var slot_name := ""
		var anim_name := "slide_in"

		if tokens.size() == 1:
			expr_name = tokens[0]
		elif tokens.size() == 2:
			expr_name = tokens[0]
			slot_name = tokens[1]
		elif tokens.size() == 3:
			char_name = tokens[0]
			expr_name = tokens[1]
			slot_name = tokens[2]
		elif tokens.size() >= 4:
			char_name = tokens[0]
			expr_name = tokens[1]
			slot_name = tokens[2]
			anim_name = tokens[3]

		if not char_name.is_empty():
			show_portrait(char_name, expr_name, slot_name, anim_name)


func _ensure_primary_speaker_slot(speaker: String) -> void:
	var normalized_speaker := speaker.strip_edges().to_lower()
	if normalized_speaker not in ["sherry", "雪莉", "mew", "喵呜", "喵斯", "mews", "卡琳娜", "卡琳娜·喵斯", "炉边烤鱼的少女", "luca", "卢卡", "enzuo", "enzo", "恩佐"]:
		return

	var target_slot_name := DialoguePortraitDatabase.get_default_slot_for_character(speaker)
	var target_slot := get_slot(target_slot_name)
	if target_slot == null:
		return

	var expression := "default"
	for slot in [left_slot, center_slot, right_slot]:
		if not is_instance_valid(slot) or not slot.is_active:
			continue
		if slot.current_character.strip_edges().to_lower() != normalized_speaker:
			continue
		expression = slot.current_expression
		if slot != target_slot:
			slot.clear_instant()

	if not target_slot.is_active or target_slot.current_character.strip_edges().to_lower() != normalized_speaker:
		target_slot.show_portrait(speaker, expression, "fade_in")


func _update_portrait_focus(speaking_character: String) -> void:
	var clean_speaker := speaking_character.strip_edges().to_lower()
	var slots := [left_slot, center_slot, right_slot]
	var matched_any := false

	for slot in slots:
		if not is_instance_valid(slot) or not slot.is_active:
			continue
		var matches: bool = (
			not clean_speaker.is_empty()
			and (
				slot.current_character.to_lower() == clean_speaker
				or DialoguePortraitDatabase.normalize_slot(clean_speaker) == _slot_to_name(slot)
			)
		)
		if matches:
			slot.set_focused(true)
			matched_any = true
		else:
			slot.set_focused(false)

	if not matched_any:
		for slot in slots:
			if is_instance_valid(slot) and slot.is_active:
				slot.set_focused(true)


func _slot_to_name(slot: DialoguePortraitSlot) -> String:
	if slot == left_slot:
		return "left"
	if slot == right_slot:
		return "right"
	return "center"


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_CTRL:
			var prev := _ctrl_fast_active
			_ctrl_fast_active = event.is_pressed()
			if _ctrl_fast_active != prev:
				_update_fast_button_visual()
				if _ctrl_fast_active and is_waiting_for_input and is_instance_valid(dialogue_line):
					_trigger_fast_advance()
		elif event.is_pressed() and event.keycode == KEY_ESCAPE:
			if history_panel != null and history_panel.visible:
				history_panel.hide()
				get_viewport().set_input_as_handled()


func _is_fast_forward_active() -> bool:
	return fast_mode or _ctrl_fast_active or Input.is_key_pressed(KEY_CTRL)


func _update_fast_button_visual() -> void:
	if fast_button != null:
		var active := _is_fast_forward_active()
		fast_button.modulate = Color(1.2, 0.95, 0.55) if active else Color.WHITE


func apply_dialogue_line() -> void:
	_mutation_cooldown.stop()
	progress.hide()
	progress_mark.set_playing(false)
	is_waiting_for_input = false

	var clean_speaker := _clean_character_name(dialogue_line.character)
	character_label.visible = not clean_speaker.is_empty()
	character_label.text = tr(clean_speaker, "dialogue")
	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line
	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses
	_append_history(dialogue_line)
	_process_portrait_syntax(dialogue_line)

	will_hide_balloon = false
	var current_line_id := dialogue_line.id
	if not _has_entered:
		await _play_enter_transition()
		if not is_instance_valid(dialogue_line) or dialogue_line.id != current_line_id:
			return
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()
	dialogue_label.show()

	var fast_active := _is_fast_forward_active()
	if fast_active:
		dialogue_label.skip_typing()
	elif not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if not is_instance_valid(dialogue_line) or dialogue_line.id != current_line_id:
		return

	var has_selectable_responses := not responses_menu.get_menu_items().is_empty()
	if has_selectable_responses:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.responses.size() > 0:
		# Every conditional response failed. Continue instead of showing an
		# empty, unfocusable response menu.
		next(dialogue_line.next_id)
	elif _is_fast_forward_active():
		await get_tree().create_timer(0.2).timeout
		_complete_fast_forward_wait(current_line_id)
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
	if history_panel != null:
		history_panel.hide()
	if not _is_rolling_back:
		_save_history_snapshot()
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


func _save_history_snapshot() -> void:
	if not is_instance_valid(dialogue_line):
		return
	var snapshot := {
		"line": dialogue_line,
		"character": dialogue_line.character,
		"text": dialogue_line.text,
		"tags": dialogue_line.tags.duplicate() if dialogue_line.tags != null else PackedStringArray(),
		"time": dialogue_line.time,
		"responses": dialogue_line.responses.duplicate() if dialogue_line.responses != null else [],
		"left_active": left_slot.is_active if left_slot != null else false,
		"left_char": left_slot.current_character if left_slot != null else "",
		"left_expr": left_slot.current_expression if left_slot != null else "default",
		"center_active": center_slot.is_active if center_slot != null else false,
		"center_char": center_slot.current_character if center_slot != null else "",
		"center_expr": center_slot.current_expression if center_slot != null else "default",
		"right_active": right_slot.is_active if right_slot != null else false,
		"right_char": right_slot.current_character if right_slot != null else "",
		"right_expr": right_slot.current_expression if right_slot != null else "default",
	}
	_history_stack.append(snapshot)
	if _history_stack.size() > 50:
		_history_stack.pop_front()


func _restore_history_snapshot(snapshot: Dictionary) -> void:
	_is_rolling_back = true
	_mutation_cooldown.stop()
	progress.hide()
	progress_mark.set_playing(false)
	is_waiting_for_input = false

	# Restore portrait slots
	_restore_slot(left_slot, snapshot.get("left_active", false), snapshot.get("left_char", ""), snapshot.get("left_expr", "default"))
	_restore_slot(center_slot, snapshot.get("center_active", false), snapshot.get("center_char", ""), snapshot.get("center_expr", "default"))
	_restore_slot(right_slot, snapshot.get("right_active", false), snapshot.get("right_char", ""), snapshot.get("right_expr", "default"))

	# Restore character name
	var raw_char: String = snapshot.get("character", "")
	var clean_speaker := _clean_character_name(raw_char)
	character_label.visible = not clean_speaker.is_empty()
	character_label.text = tr(clean_speaker, "dialogue")

	# Restore dialogue line & immediate text display
	var prev_line: DialogueLine = snapshot.get("line")
	dialogue_line = prev_line
	dialogue_label.dialogue_line = prev_line
	dialogue_label.show()
	dialogue_label.skip_typing()

	# Restore responses
	responses_menu.hide()
	var responses: Array = snapshot.get("responses", [])
	responses_menu.responses = responses
	if not responses.is_empty():
		responses_menu.show()

	_update_portrait_focus(clean_speaker)
	is_waiting_for_input = true
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()
	_is_rolling_back = false


func _restore_slot(slot: DialoguePortraitSlot, active: bool, character_name: String, expression: String) -> void:
	if slot == null:
		return
	if active and not character_name.is_empty():
		slot.show_portrait(character_name, expression, "fade_in")
	else:
		slot.clear_instant()


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
	_set_dialogue_targets_locked(false)
	clear_portraits()
	if owner == null:
		queue_free()
	else:
		hide()
	_is_closing = false


func _set_dialogue_targets_locked(locked: bool) -> void:
	if _dialogue_targets_locked == locked:
		return
	_dialogue_targets_locked = locked
	for target in get_tree().get_nodes_in_group("dialogue_lockable"):
		if is_instance_valid(target) and target.has_method("set_dialogue_locked"):
			target.call("set_dialogue_locked", locked)


func _kill_transition_tween() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


func _append_history(line: DialogueLine) -> void:
	var clean_speaker := _clean_character_name(line.character)
	var speaker := tr(clean_speaker, "dialogue")
	var body := tr(line.text, "dialogue")
	if not speaker.is_empty():
		_history.append("[color=#e5be7a][b]◆ %s[/b][/color]\n[color=#eae2d5]%s[/color]" % [speaker, body])
	else:
		_history.append("[color=#c2b7a3][i]%s[/i][/color]" % [body])
	if _history.size() > 40:
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
	fast_mode = not fast_mode
	_update_fast_button_visual()
	_show_status("快进模式：开启 (0.2s/页)" if fast_mode else "快进模式：关闭")
	if fast_mode:
		if dialogue_label.is_typing:
			dialogue_label.skip_typing()
		elif is_waiting_for_input and is_instance_valid(dialogue_line):
			_trigger_fast_advance()


func _trigger_fast_advance() -> void:
	if not is_waiting_for_input or not is_instance_valid(dialogue_line) or not responses_menu.get_menu_items().is_empty():
		return
	var current_line_id := dialogue_line.id
	is_waiting_for_input = false
	dialogue_label.skip_typing()
	await get_tree().create_timer(0.2).timeout
	_complete_fast_forward_wait(current_line_id)


func _complete_fast_forward_wait(current_line_id: String) -> void:
	if not is_instance_valid(dialogue_line) or dialogue_line.id != current_line_id:
		return
	if _is_fast_forward_active():
		next(dialogue_line.next_id)
		return

	# Fast mode can be released while its page-delay timer is running. Restore
	# the normal input state instead of leaving this line without a progression path.
	is_waiting_for_input = true
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()


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
	if history_panel != null:
		history_panel.hide()
	if _history_stack.is_empty():
		_show_status("已是第一句话")
		return

	var prev_snapshot: Dictionary = _history_stack.pop_back()
	_restore_history_snapshot(prev_snapshot)
	_show_status("已回退至上一句")


func _on_history_pressed() -> void:
	if _is_transitioning or _is_closing:
		return
	history_panel.visible = not history_panel.visible
	if history_panel.visible:
		history_label.text = "\n\n".join(_history)
		history_label.scroll_to_line(maxi(0, history_label.get_line_count() - 1))


func _on_history_close_pressed() -> void:
	if history_panel != null:
		history_panel.hide()


func _on_settings_pressed() -> void:
	if _is_transitioning or _is_closing:
		return
	if history_panel != null:
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
	if history_panel != null:
		history_panel.hide()
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
