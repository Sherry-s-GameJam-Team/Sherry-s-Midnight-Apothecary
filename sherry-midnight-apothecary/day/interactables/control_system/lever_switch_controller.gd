class_name LeverSwitchController
extends ControllerBase

## 拉杆开关：玩家进入交互范围后按 E（interact）切换或保持激活状态。

@export var interact_action := &"interact"
@export var toggle_mode := true

@onready var _area: Area2D = $Area2D
@onready var _visual: Polygon2D = $Visual
@onready var _lever: Polygon2D = $Visual/Lever
@onready var _hint_label: Label = $HintLabel

var _player_inside := false


func _ready() -> void:
	super()
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	if _hint_label != null:
		_hint_label.visible = false
	_update_visual()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or get_tree().has_meta("day_modal_input_locked"):
		return
	if event.is_action_pressed(interact_action):
		if toggle_mode:
			toggle()
		else:
			set_active(true)
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_inside = true
		if _hint_label != null:
			_hint_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_inside = false
		if _hint_label != null:
			_hint_label.visible = false


func _update_visual() -> void:
	if _visual == null or _lever == null:
		return
	_visual.color = active_color if is_active else inactive_color
	_lever.rotation_degrees = 35.0 if is_active else -35.0
