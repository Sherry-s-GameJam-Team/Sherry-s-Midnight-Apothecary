class_name ForestArvisTreeGate
extends Node2D

signal opened
signal open_requested

var is_open := false
var _opening := false
var _ready_to_open := false
var _player_in_range := false

@onready var animation: AnimatedSprite2D = $Animation
@onready var static_open: Sprite2D = $OpenStatic
@onready var blocker: CollisionShape2D = $Blocker/CollisionShape2D
@onready var audio: AudioStreamPlayer2D = $OpenSFX
@onready var interaction_zone: Area2D = $InteractionZone

func _ready() -> void:
	animation.visible = not is_open
	static_open.visible = is_open
	blocker.disabled = is_open
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)
	if not is_open:
		animation.play(&"closed")

func open_gate(skip_animation := false) -> void:
	if is_open or _opening:
		return
	_opening = true
	_ready_to_open = false
	_hide_interaction_hint()
	blocker.set_deferred("disabled", true)
	if skip_animation:
		_finish_open()
		return
	audio.play()
	animation.visible = true
	static_open.visible = false
	animation.play(&"open")
	await animation.animation_finished
	_finish_open()

func restore_open() -> void:
	is_open = true
	_opening = false
	animation.visible = false
	static_open.visible = true
	blocker.disabled = true
	_ready_to_open = false
	_hide_interaction_hint()

func set_ready_to_open(ready: bool) -> void:
	_ready_to_open = ready and not is_open and not _opening
	if _ready_to_open and _player_in_range:
		_show_interaction_hint()
	else:
		_hide_interaction_hint()

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_to_open or not _player_in_range or not _is_interact_event(event):
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
	open_requested.emit()

func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player":
		return
	_player_in_range = true
	if _ready_to_open:
		_show_interaction_hint()

func _on_body_exited(body: Node2D) -> void:
	if body.name != "Player":
		return
	_player_in_range = false
	_hide_interaction_hint()

func _is_interact_event(event: InputEvent) -> bool:
	if InputMap.has_action(&"interact") and event.is_action_pressed(&"interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_E

func _show_interaction_hint() -> void:
	var hint := _find_top_hint()
	if hint != null:
		hint.show_interaction_hint(_hint_id(), "按[E]开启树心之门")

func _hide_interaction_hint() -> void:
	var hint := _find_top_hint()
	if hint != null:
		hint.hide_interaction_hint(_hint_id())

func _find_top_hint() -> TopHintUI:
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI

func _hint_id() -> String:
	return "interaction_tree_gate_%s" % get_instance_id()

func _finish_open() -> void:
	is_open = true
	_opening = false
	animation.visible = false
	static_open.visible = true
	opened.emit()
