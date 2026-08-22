class_name BossBoxSpawner
extends Node2D

const PUSH_BOX_SCRIPT := preload("res://day/levels/lake_bottom/scripts/boss_push_box.gd")

@export var box_texture: Texture2D
@export_node_path("Marker2D") var spawn_marker_path: NodePath
@export_range(1, 1, 1) var maximum_boxes := 1
@export_range(0.1, 20.0, 0.1) var spawn_interval := 5.0
@export var box_scale := Vector2(0.14, 0.14)
@export var box_collision_size := Vector2(176, 176)

var _active := false
var _spawn_timer := 0.0
var _spawned_boxes: Array[RigidBody2D] = []

@onready var spawn_marker: Marker2D = get_node_or_null(spawn_marker_path) as Marker2D


func _process(delta: float) -> void:
	if not _active:
		return
	_prune_boxes()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _spawned_boxes.size() < maximum_boxes:
		_spawn_box()
		_spawn_timer = spawn_interval


func activate() -> void:
	if _active:
		return
	_active = true
	_spawn_timer = 0.0


func deactivate() -> void:
	_active = false
	_spawn_timer = 0.0
	for box in _spawned_boxes:
		if is_instance_valid(box):
			box.queue_free()
	_spawned_boxes.clear()
	for box in get_tree().get_nodes_in_group("lake_boss_push_boxes"):
		if box.get_meta("boss_box_spawner_id", -1) == get_instance_id() and is_instance_valid(box):
			box.queue_free()


func _spawn_box() -> void:
	if box_texture == null or spawn_marker == null:
		push_warning("BossBoxSpawner needs box_texture and spawn_marker_path.")
		return
	var box := RigidBody2D.new()
	box.set_script(PUSH_BOX_SCRIPT)
	box.name = "PushBox"
	box.global_position = spawn_marker.global_position
	# A CharacterBody2D can now reliably shove the crate while it remains heavy
	# enough to be drawn into the Tide Eye instead of bouncing away.
	box.mass = 1.0
	box.gravity_scale = 1.0
	box.lock_rotation = true
	box.linear_damp = 0.7
	box.angular_damp = 8.0
	box.collision_layer = 1
	box.collision_mask = 1
	box.z_index = 12
	box.add_to_group("lake_boss_push_boxes")
	box.set_meta("boss_box_spawner_id", get_instance_id())

	var sprite := Sprite2D.new()
	sprite.texture = box_texture
	sprite.scale = box_scale
	box.add_child(sprite)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = box_collision_size
	collision.shape = shape
	box.add_child(collision)

	var level := get_parent().get_parent()
	if level == null:
		box.queue_free()
		return
	level.add_child(box)
	_spawned_boxes.append(box)


func _prune_boxes() -> void:
	var retained_boxes: Array[RigidBody2D] = []
	for box in _spawned_boxes:
		if is_instance_valid(box):
			retained_boxes.append(box)
	_spawned_boxes = retained_boxes
