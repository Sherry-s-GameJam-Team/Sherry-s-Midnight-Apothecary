extends Area2D

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var dialogue_resource: DialogueResource
@export var before_stream_dialogue: DialogueResource
@export var after_stream_dialogue: DialogueResource
@export var gate_path: NodePath
@export var dialogue_title := "start"
@export var interaction_hint_text := "按[E]与卢卡交谈"

var _player: Node2D
var _played_dialogue_stages: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player" or _has_played_current_dialogue():
		return
	_player = body
	_show_interaction_hint()

func _on_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	_player = null
	_hide_interaction_hint()

func _unhandled_input(event: InputEvent) -> void:
	if _player == null or _has_played_current_dialogue() or not _is_interact_event(event):
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
	_start_dialogue()

func _start_dialogue() -> void:
	var active_dialogue := _active_dialogue()
	if active_dialogue == null:
		push_error("LucaDialogueNpc has no dialogue assigned for the current gate state.")
		return

	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null or not dialogue_manager.has_method("show_dialogue_balloon_scene"):
		push_error("找不到 DialogueManager 自动加载。")
		return

	_played_dialogue_stages[_dialogue_stage()] = true
	_hide_interaction_hint()
	dialogue_manager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		active_dialogue,
		dialogue_title
	)

func _is_interact_event(event: InputEvent) -> bool:
	if InputMap.has_action(&"interact") and event.is_action_pressed(&"interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_E

func _show_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)

func _hide_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())

func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI

func _hint_id() -> String:
	return "interaction_%s" % get_instance_id()

func _active_dialogue() -> DialogueResource:
	if _is_gate_open():
		return after_stream_dialogue if after_stream_dialogue != null else dialogue_resource
	return before_stream_dialogue if before_stream_dialogue != null else dialogue_resource

func _dialogue_stage() -> StringName:
	return &"after_stream" if _is_gate_open() else &"before_stream"

func _has_played_current_dialogue() -> bool:
	return bool(_played_dialogue_stages.get(_dialogue_stage(), false))

func _is_gate_open() -> bool:
	var gate := get_node_or_null(gate_path) as ForestArvisTreeGate
	return gate != null and gate.is_open
