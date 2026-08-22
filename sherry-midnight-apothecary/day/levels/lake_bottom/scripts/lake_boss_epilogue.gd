class_name LakeBossEpilogue
extends Node2D

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var dialogue_resource: DialogueResource
@export_node_path("CharacterBody2D") var player_path: NodePath

var _playing := false
var _water_level := 0.0

@onready var boat: Node2D = $Boat
@onready var player: CharacterBody2D = get_node_or_null(player_path) as CharacterBody2D


func _ready() -> void:
	boat.visible = false
	queue_redraw()


func play() -> void:
	if _playing:
		return
	_playing = true
	boat.visible = true
	if player != null:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	var water_tween := create_tween()
	water_tween.tween_method(_set_water_level, 0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_shake_camera()
	await water_tween.finished
	var voyage := create_tween()
	voyage.tween_property(boat, "position:x", boat.position.x + 2500.0, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_start_dialogue()


func _process(_delta: float) -> void:
	if _playing and player != null and boat.visible:
		player.global_position = boat.global_position + Vector2(-38.0, -66.0)


func _draw() -> void:
	if _water_level <= 0.0:
		return
	var top := lerpf(1120.0, 370.0, _water_level)
	draw_rect(Rect2(-500.0, top, 10800.0, 1300.0), Color(0.05, 0.70, 0.82, 0.58))
	for index in range(7):
		var y := top + 30.0 + index * 94.0
		draw_line(Vector2(-300.0, y), Vector2(10100.0, y - 20.0), Color(0.52, 1.0, 1.0, 0.30), 5.0)


func _set_water_level(value: float) -> void:
	_water_level = value
	queue_redraw()


func _shake_camera() -> void:
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var origin := camera.offset
	var shake := create_tween()
	for index in range(8):
		shake.tween_property(camera, "offset", origin + Vector2(10.0 if index % 2 == 0 else -10.0, 5.0), 0.07)
	shake.tween_property(camera, "offset", origin, 0.12)


func _start_dialogue() -> void:
	if dialogue_resource == null:
		_finish()
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		_finish()
		return
	get_tree().set_meta("day_modal_input_locked", true)
	var balloon := dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, &"start") as Node
	if balloon != null:
		balloon.tree_exited.connect(_finish, CONNECT_ONE_SHOT)
	else:
		_finish()


func _finish() -> void:
	var runtime := _find_day_runtime()
	if runtime != null:
		runtime.transition_to_level_with_blackout("golden_cliff_village", &"from_lake", true)


func _find_day_runtime() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("transition_to_level_with_blackout"):
			return current
		current = current.get_parent()
	return null
