class_name ProcessBoardDropSurface
extends Control

@export var process_board_path := NodePath("../..")
@export var follow_control_path := NodePath()

@onready var process_board: ProcessBoard = get_node_or_null(process_board_path) as ProcessBoard
@onready var follow_control: Control = get_node_or_null(follow_control_path) as Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_follow_control()
	if follow_control != null and not follow_control.item_rect_changed.is_connected(_sync_follow_control):
		follow_control.item_rect_changed.connect(_sync_follow_control)
	var parent_control := get_parent() as Control
	if parent_control != null and not parent_control.resized.is_connected(_sync_follow_control):
		parent_control.resized.connect(_sync_follow_control)


func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if process_board == null or data is not Dictionary:
		return false
	# This Control already is the exact drop boundary. Rechecking a transformed
	# position here caused valid native drag callbacks to be rejected.
	if data.get("kind") == &"herb":
		return true
	return process_board._can_drop_data(_to_board_position(position), data)


func _drop_data(position: Vector2, data: Variant) -> void:
	if process_board == null or data is not Dictionary:
		return
	if data.get("kind") == &"herb":
		process_board.herb_dropped.emit(StringName(str(data.get("ingredient_id", ""))))
		return
	process_board._drop_data(_to_board_position(position), data)


func _to_board_position(position: Vector2) -> Vector2:
	var global_point := get_global_transform() * position
	return process_board.get_global_transform().affine_inverse() * global_point


func _sync_follow_control() -> void:
	if follow_control == null or process_board == null or get_parent() is not CanvasItem:
		return
	var target_rect := process_board.get_global_control_rect(follow_control)
	var parent_inverse := (get_parent() as CanvasItem).get_global_transform().affine_inverse()
	var local_start := parent_inverse * target_rect.position
	var local_end := parent_inverse * target_rect.end
	position = local_start
	size = local_end - local_start
