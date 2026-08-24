class_name ForestEnzuoSavedInteraction
extends Node2D

## The post-Boss Enzuo scene is intentionally player initiated.  Returning to
## Forest only reveals Enzuo; the event is dispatched after an E interaction.

const ACTIVE_DAY := 2
const FOREST_COMPLETED_FLAG: StringName = &"forest_completed"
const SOLVED_FLAG: StringName = &"save_enzuo_solved"
const EVENT_ID: StringName = &"day_two_forest_enzuo_saved"
const INTERACTION_KEY: StringName = &"day_two_forest_enzuo_saved"

@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("Node2D") var enzuo_path: NodePath
@export var interaction_radius := 150.0

var _player: CharacterBody2D
var _enzuo: Node2D
var _runtime: Node
var _hint: TopHintUI
var _hint_id := "forest_enzuo_fall"
var _starting := false


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_enzuo = get_node_or_null(enzuo_path) as Node2D
	_resolve_runtime()
	visible = should_show(_current_day(), _player_data())
	if _runtime != null:
		_runtime.connect(&"story_event_completed", _on_story_event_completed)


func _exit_tree() -> void:
	_hide_hint()


func _process(_delta: float) -> void:
	if not should_show(_current_day(), _player_data()):
		visible = false
		_hide_hint()
		return
	visible = true
	if _starting or _player == null or _enzuo == null:
		return
	if _player.global_position.distance_to(_enzuo.global_position) <= interaction_radius:
		_show_hint()
	else:
		_hide_hint()


func _unhandled_input(event: InputEvent) -> void:
	if _starting or _player == null or _enzuo == null or not event.is_action_pressed("interact"):
		return
	if _player.global_position.distance_to(_enzuo.global_position) > interaction_radius:
		return
	if _runtime == null or not bool(_runtime.call("dispatch_story_event_interaction", INTERACTION_KEY)):
		return
	_starting = true
	_hide_hint()
	get_viewport().set_input_as_handled()


static func should_show(day: int, player_data: PlayerData) -> bool:
	return day == ACTIVE_DAY and player_data != null \
		and bool(player_data.tutorial_flags.get(FOREST_COMPLETED_FLAG, false)) \
		and not player_data.has_event_flag(SOLVED_FLAG)


func _on_story_event_completed(event_id: StringName) -> void:
	if event_id == EVENT_ID:
		visible = false
		_hide_hint()


func _show_hint() -> void:
	if _hint == null:
		_hint = get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	if _hint != null:
		_hint.show_interaction_hint(_hint_id, "按 E 查看恩佐")


func _hide_hint() -> void:
	if _hint != null:
		_hint.hide_interaction_hint(_hint_id)


func _current_day() -> int:
	return int(_runtime.get("day")) if _runtime != null else -1


func _player_data() -> PlayerData:
	return _runtime.call("get_player_data") as PlayerData if _runtime != null else null


func _resolve_runtime() -> void:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data") and current.has_method("switch_to_level"):
			_runtime = current
			return
		current = current.get_parent()
