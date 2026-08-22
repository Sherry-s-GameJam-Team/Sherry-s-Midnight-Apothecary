class_name VillageLakeReturn
extends Node

## Owns the one-time dock reunion after the Tide Eye has been defeated.
## The boat/water loop lives under `saved` so it remains visible on later
## village visits after this sequence has played.

const TIDE_EYE_DEFEATED_FLAG: StringName = &"lake_bottom_tide_eye_defeated"
const RETURN_COMPLETED_FLAG: StringName = &"lake_bottom_village_return_completed"
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var dialogue_resource: DialogueResource

var _presentation_started := false
var _dialogue_open := false
var _modal_lock_was_set := false

@onready var saved_root: CanvasItem = get_parent().get_node_or_null("CS/saved") as CanvasItem
@onready var boat: CanvasItem = get_parent().get_node_or_null("CS/saved/Boat") as CanvasItem
@onready var idle_loop: AnimatedSprite2D = get_parent().get_node_or_null("CS/saved/IdleLoop") as AnimatedSprite2D


func _ready() -> void:
	_set_saved_presentation_visible(_has_defeated_tide_eye())


func on_level_entered(entry_id: StringName) -> void:
	if entry_id != &"from_bottom" or not _has_defeated_tide_eye():
		return
	_set_saved_presentation_visible(true)
	if _has_completed_return() or _presentation_started:
		return
	_presentation_started = true
	call_deferred("_play_return_dialogue")


func _play_return_dialogue() -> void:
	# Start after the blackout has faded back in, so the first dock image and
	# Mew's lookout line are visible before the dialogue box appears.
	await get_tree().create_timer(0.45).timeout
	if _has_completed_return() or dialogue_resource == null:
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("VillageLakeReturn requires the DialogueManager autoload.")
		return
	_dialogue_open = true
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	var balloon := dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, &"start") as Node
	if balloon != null:
		balloon.tree_exited.connect(_finish_return, CONNECT_ONE_SHOT)
	else:
		_finish_return()


func _finish_return() -> void:
	if not _dialogue_open:
		return
	_dialogue_open = false
	var player_data := _get_player_data()
	if player_data != null:
		player_data.set_event_flag(RETURN_COMPLETED_FLAG)
	if not _modal_lock_was_set and is_inside_tree():
		get_tree().remove_meta("day_modal_input_locked")


func _set_saved_presentation_visible(visible: bool) -> void:
	if saved_root != null:
		saved_root.visible = visible
	if boat != null:
		boat.visible = visible
	if idle_loop != null:
		idle_loop.visible = visible
		if visible:
			idle_loop.play(&"idle_loop")


func _has_defeated_tide_eye() -> bool:
	var player_data := _get_player_data()
	return player_data != null and player_data.has_event_flag(TIDE_EYE_DEFEATED_FLAG)


func _has_completed_return() -> bool:
	var player_data := _get_player_data()
	return player_data != null and player_data.has_event_flag(RETURN_COMPLETED_FLAG)


func _get_player_data() -> PlayerData:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return null
