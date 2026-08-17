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
	var inside := false
	for body in get_overlapping_bodies():
		if body.name == "Luca" or body.name == "Player" or body.is_in_group("player") or body.is_in_group("forest_luca_runtime"):
			inside = true
			break
	_luca_inside = inside
	prompt.visible = _luca_inside
	prompt.text = "[E] 乘直达升降梯" if _unlocked else "直达升降梯尚未恢复"


func _unhandled_input(event: InputEvent) -> void:
	if not _unlocked or not _luca_inside:
		return
	var is_e: bool = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.keycode == KEY_E))
	if is_e:
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		var level := _get_level()
		if level == null:
			return
		var destination: Marker2D = null
		if level.has_node(destination_path):
			destination = level.get_node_or_null(destination_path) as Marker2D
		elif has_node(destination_path):
			destination = get_node_or_null(destination_path) as Marker2D
		else:
			destination = level.get_node_or_null("RespawnPoints/LucaTopArrival") as Marker2D
		
		var active_body: CharacterBody2D = null
		if level.is_luca_active():
			active_body = level.get_node_or_null("Luca") as CharacterBody2D
		else:
			active_body = level.get_node_or_null("Player") as CharacterBody2D
		
		if destination != null and active_body != null:
			active_body.velocity = Vector2.ZERO
			active_body.global_position = destination.global_position


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Luca" or body.name == "Player" or body.is_in_group("player") or body.is_in_group("forest_luca_runtime"):
		_luca_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Luca" or body.name == "Player" or body.is_in_group("player") or body.is_in_group("forest_luca_runtime"):
		_luca_inside = false


func _is_luca_active() -> bool:
	var level := _get_level()
	if level != null and level.has_method("is_luca_active"):
		return bool(level.call("is_luca_active"))
	return true


func _get_level() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.has_method("is_luca_active"):
			return cursor
		cursor = cursor.get_parent()
	if is_inside_tree() and get_tree() != null:
		var grp := get_tree().get_nodes_in_group("forest_interior_level")
		if not grp.is_empty():
			return grp[0]
	return null
