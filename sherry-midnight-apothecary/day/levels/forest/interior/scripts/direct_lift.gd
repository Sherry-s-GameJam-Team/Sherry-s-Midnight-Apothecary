class_name ForestDirectLift
extends Area2D

@export var destination_path: NodePath

@onready var prompt: Label = $Prompt

var _luca_inside := false
var _unlocked := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false


func set_unlocked(value: bool) -> void:
	_unlocked = value
	modulate = Color.WHITE if value else Color(0.55, 0.55, 0.55, 0.8)


func _process(_delta: float) -> void:
	prompt.visible = _luca_inside and _is_luca_active()
	prompt.text = "[E] 乘升降梯" if _unlocked else "升降梯尚未恢复"


func _unhandled_input(event: InputEvent) -> void:
	if not _unlocked or not _luca_inside or not _is_luca_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		var level := _get_level()
		if level == null:
			return
		var destination := level.get_node_or_null(destination_path) as Marker2D
		var luca := level.get_node_or_null("Luca") as CharacterBody2D
		if destination != null and luca != null:
			luca.velocity = Vector2.ZERO
			luca.global_position = destination.global_position
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Luca":
		_luca_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Luca":
		_luca_inside = false


func _is_luca_active() -> bool:
	var level := _get_level()
	return level != null and level.is_luca_active()


func _get_level() -> ForestInteriorLevel:
	var cursor: Node = self
	while cursor != null:
		if cursor is ForestInteriorLevel:
			return cursor as ForestInteriorLevel
		cursor = cursor.get_parent()
	return null
