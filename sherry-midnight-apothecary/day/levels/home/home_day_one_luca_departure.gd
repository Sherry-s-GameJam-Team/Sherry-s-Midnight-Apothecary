class_name HomeDayOneLucaDeparture
extends Node

## Starts the second half of the day-one Luca scene once Sherry crosses from
## the bedroom side through BedroomEntrance into Home's main room.

const BEDROOM_EVENT_ID: StringName = &"day_one_bedroom_luca_urgent"
const EVENT_ID: StringName = &"day_one_home_luca_departure"
const INTERACTION_KEY: StringName = &"day_one_home_luca_departure"

@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("Area2D") var bedroom_entrance_path: NodePath
@export_node_path("CanvasItem") var luca_path: NodePath

var _player: CharacterBody2D
var _bedroom_entrance: Area2D
var _luca: CanvasItem
var _requested := false


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_bedroom_entrance = get_node_or_null(bedroom_entrance_path) as Area2D
	_luca = get_node_or_null(luca_path) as CanvasItem
	if _luca != null:
		_luca.visible = false
	set_process(_player != null and _bedroom_entrance != null)


func _process(_delta: float) -> void:
	if _player == null or _bedroom_entrance == null:
		return
	# HomeCameraDirector disables the Area2D after the player exits Bedroom, so
	# the controller detects the same spatial crossing directly from the player.
	if _player.global_position.x >= _bedroom_entrance.global_position.x:
		_request_departure_dialogue()


func _request_departure_dialogue() -> void:
	if _requested or not _can_play():
		return
	var runtime := _find_day_runtime()
	if runtime == null:
		return
	_requested = bool(runtime.call("dispatch_story_event_interaction", INTERACTION_KEY))
	if not _requested:
		return
	set_process(false)
	if _luca != null:
		_luca.visible = true
	runtime.connect(&"story_event_completed", _on_story_event_completed, CONNECT_ONE_SHOT)


func _on_story_event_completed(event_id: StringName) -> void:
	if event_id == EVENT_ID and _luca != null:
		_luca.visible = false


func _can_play() -> bool:
	var runtime := _find_day_runtime()
	return runtime != null \
		and int(runtime.get("day")) == 1 \
		and bool(runtime.call("has_completed_story_event", BEDROOM_EVENT_ID)) \
		and not bool(runtime.call("has_completed_story_event", EVENT_ID))


func _find_day_runtime() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data") and current.has_method("switch_to_level"):
			return current
		current = current.get_parent()
	return null
