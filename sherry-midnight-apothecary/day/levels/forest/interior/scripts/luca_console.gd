class_name ForestLucaConsole
extends Area2D

@export var action_id: StringName
@export var one_shot := false
@export var operator_name: StringName = &"Luca"
@export var prompt_text := "[E] 操作机关"

@onready var prompt: Label = $Prompt

var _operator_inside := false
var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _used and one_shot:
		return
	if not _operator_inside or not _is_operator_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		var level := _get_level()
		if level != null and level.activate_luca_console(action_id):
			if one_shot:
				_used = true
				modulate = Color(0.65, 0.95, 0.8, 0.75)
				prompt.visible = false
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	prompt.text = prompt_text
	prompt.visible = _operator_inside and _is_operator_active() and not (_used and one_shot)


func _on_body_entered(body: Node2D) -> void:
	if body.name == operator_name:
		_operator_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == operator_name:
		_operator_inside = false


func _is_operator_active() -> bool:
	var level := _get_level()
	if level == null:
		return false
	if operator_name == &"Player":
		return not level.is_luca_active()
	return level.is_luca_active()


func _get_level() -> ForestInteriorLevel:
	var cursor: Node = self
	while cursor != null:
		if cursor is ForestInteriorLevel:
			return cursor as ForestInteriorLevel
		cursor = cursor.get_parent()
	return null
