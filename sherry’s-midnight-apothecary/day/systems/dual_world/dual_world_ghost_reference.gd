@tool
class_name DualWorldGhostReference
extends Node2D

@export var reference_scene: PackedScene:
	set(value):
		reference_scene = value
		_queue_refresh()

@export_range(0.2, 0.35, 0.01) var preview_alpha := 0.25:
	set(value):
		preview_alpha = value
		if is_instance_valid(_ghost):
			_ghost.modulate.a = preview_alpha

@export var preview_enabled := true:
	set(value):
		preview_enabled = value
		_queue_refresh()

var _ghost: Node2D


func _ready() -> void:
	if Engine.is_editor_hint():
		_queue_refresh()


func _queue_refresh() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		call_deferred("_refresh")


func _refresh() -> void:
	if not Engine.is_editor_hint():
		return
	if is_instance_valid(_ghost):
		_ghost.free()
		_ghost = null
	if not preview_enabled or reference_scene == null:
		return
	var instance := reference_scene.instantiate()
	if not instance is Node2D:
		push_warning("Dual-world ghost reference root must inherit Node2D.")
		instance.free()
		return
	_ghost = instance as Node2D
	add_child(_ghost, false, Node.INTERNAL_MODE_FRONT)
	_ghost.transform = Transform2D.IDENTITY
	_ghost.modulate = Color(1.0, 1.0, 1.0, preview_alpha)
	_disable_runtime_nodes(_ghost)


func _disable_runtime_nodes(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", true)
	for child: Node in node.get_children():
		_disable_runtime_nodes(child)
