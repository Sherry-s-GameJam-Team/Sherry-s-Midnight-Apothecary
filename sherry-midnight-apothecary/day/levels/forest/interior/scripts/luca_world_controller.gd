class_name ForestInteriorLucaWorldController
extends Node

@export var luca_world_path: NodePath
@export var overlay_path: NodePath

var _enabled := false


func set_luca_view(enabled: bool) -> void:
	_enabled = enabled
	var world := get_node_or_null(luca_world_path) as CanvasItem
	if world != null:
		world.visible = enabled
	var overlay := get_node_or_null(overlay_path) as CanvasItem
	if overlay != null:
		overlay.visible = enabled


func is_luca_view_enabled() -> bool:
	return _enabled
