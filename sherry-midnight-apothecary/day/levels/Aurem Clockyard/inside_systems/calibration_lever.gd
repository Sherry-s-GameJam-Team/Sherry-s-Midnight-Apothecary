class_name CalibrationLever
extends Area2D

signal lever_pulled

@export var target_gears: Array[NodePath] = []
@export var sync_duration: float = 6.0

var _is_active: bool = false
var _remaining_time: float = 0.0
var _player_in_range: bool = false

@onready var handle_sprite: Sprite2D = get_node_or_null("HandleSprite")
@onready var timer_label: Label = get_node_or_null("TimerLabel")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if timer_label != null:
		timer_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact"):
		pull_lever()
		get_viewport().set_input_as_handled()


func pull_lever() -> void:
	_is_active = true
	_remaining_time = sync_duration
	lever_pulled.emit()

	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_clack"):
				audio.call("play_gear_clack")

	if handle_sprite != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(handle_sprite, "rotation_degrees", 45.0, 0.2)

	for path in target_gears:
		var node := get_node_or_null(path)
		if node != null:
			if node.has_method("set_synchronized"):
				node.call("set_synchronized", true, sync_duration)
			elif node.has_method("toggle_lift"):
				node.call("toggle_lift")

	if timer_label != null:
		timer_label.visible = true


func receive_potion_hit(_hit: Dictionary) -> void:
	pull_lever()


func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	_remaining_time -= delta
	if timer_label != null:
		timer_label.text = "%.1fs" % maxf(_remaining_time, 0.0)

	if _remaining_time <= 0.0:
		_is_active = false
		if timer_label != null:
			timer_label.visible = false
		if handle_sprite != null:
			var tween := create_tween()
			if tween != null:
				tween.tween_property(handle_sprite, "rotation_degrees", 0.0, 0.4)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_range = true
		var top_hint := get_node_or_null("/root/TopHintUI")
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", "calib_lever", "按 E 拉动校准杆（齿轮同步）")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_range = false
		var top_hint := get_node_or_null("/root/TopHintUI")
		if top_hint != null and top_hint.has_method("hide_hint"):
			top_hint.call("hide_hint", "calib_lever")
