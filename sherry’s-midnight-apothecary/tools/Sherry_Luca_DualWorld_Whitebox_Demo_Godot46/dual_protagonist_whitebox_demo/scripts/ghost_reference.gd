@tool
extends Node2D
class_name DualWorldGhostReference

@export var reference_scene: PackedScene:
    set(value):
        reference_scene = value
        _queue_refresh()

@export_range(0.05, 0.8, 0.05) var preview_alpha := 0.25:
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
        _ghost.queue_free()
        _ghost = null
    if not preview_enabled or reference_scene == null:
        return
    var instance := reference_scene.instantiate()
    if not instance is Node2D:
        push_warning("Ghost reference scene root must inherit Node2D.")
        instance.queue_free()
        return
    _ghost = instance as Node2D
    add_child(_ghost)
    _ghost.position = Vector2.ZERO
    _ghost.rotation = 0.0
    _ghost.scale = Vector2.ONE
    _ghost.modulate = Color(1, 1, 1, preview_alpha)
    _disable_runtime_nodes(_ghost)

func _disable_runtime_nodes(node: Node) -> void:
    if node is CollisionShape2D or node is CollisionPolygon2D:
        node.set_deferred("disabled", true)
    node.process_mode = Node.PROCESS_MODE_DISABLED
    for child in node.get_children():
        _disable_runtime_nodes(child)
