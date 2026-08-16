extends Area2D

@onready var prompt: Label = $Prompt
var _player_inside := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false


func _process(_delta: float) -> void:
	prompt.visible = _player_inside


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		var level := _get_level()
		if level != null:
			level.request_exit_to_crown()
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_inside = false


func _get_level() -> ForestInteriorLevel:
	var cursor: Node = self
	while cursor != null:
		if cursor is ForestInteriorLevel:
			return cursor as ForestInteriorLevel
		cursor = cursor.get_parent()
	return null
