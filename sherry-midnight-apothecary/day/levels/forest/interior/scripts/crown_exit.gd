extends Area2D

@onready var prompt: Label = $Prompt
var _player_inside := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false


func _process(_delta: float) -> void:
	var inside := false
	for body in get_overlapping_bodies():
		if body.name == "Player" or body.name == "Luca" or body.is_in_group("player") or body.is_in_group("forest_luca_runtime"):
			inside = true
			break
	_player_inside = inside
	prompt.visible = _player_inside


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	var is_e: bool = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.keycode == KEY_E))
	if is_e:
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		var level := _get_level()
		if level != null and level.has_method("request_exit_to_crown"):
			level.call("request_exit_to_crown")


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.name == "Luca" or body.is_in_group("player") or body.is_in_group("forest_luca_runtime"):
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body.name == "Luca" or body.is_in_group("player") or body.is_in_group("forest_luca_runtime"):
		_player_inside = false


func _get_level() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.has_method("request_exit_to_crown"):
			return cursor
		cursor = cursor.get_parent()
	if is_inside_tree() and get_tree() != null:
		var grp := get_tree().get_nodes_in_group("forest_interior_level")
		if not grp.is_empty():
			return grp[0]
	return null
