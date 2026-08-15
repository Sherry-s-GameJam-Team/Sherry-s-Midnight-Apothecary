class_name CliffResonanceReceiver
extends Node2D

signal receiver_activated

@onready var interact_area: Area2D = $InteractArea
@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

var _player_inside := false
var _available := false
var _activated := false
var _stable_count := 0
var _total_count := 0


func _ready() -> void:
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	_refresh_visual()


func _input(event: InputEvent) -> void:
	if _activated or not _available or not _player_inside or get_tree().has_meta("day_modal_input_locked"):
		return
	if _is_interact_event(event):
		get_viewport().set_input_as_handled()
		_activated = true
		_refresh_visual()
		receiver_activated.emit()


func set_progress(stable_count: int, total_count: int) -> void:
	_stable_count = stable_count
	_total_count = total_count
	_available = total_count > 0 and stable_count >= total_count
	_refresh_visual()


func set_activated(value: bool) -> void:
	_activated = value
	if value:
		_available = true
	_refresh_visual()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_refresh_visual()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_refresh_visual()


func _refresh_visual() -> void:
	if sprite != null:
		if _activated:
			sprite.modulate = Color(0.72, 1.0, 1.0, 1.0)
		elif _available:
			sprite.modulate = Color.WHITE
		else:
			sprite.modulate = Color(0.62, 0.72, 0.78, 1.0)
	if label == null:
		return
	label.visible = _player_inside
	if _activated:
		label.text = "鸣晶核心已归静"
	elif _available:
		label.text = "按 [E] 稳定鸣晶核心"
	else:
		label.text = "鸣晶尚未归静（%d/%d）" % [_stable_count, _total_count]


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)
