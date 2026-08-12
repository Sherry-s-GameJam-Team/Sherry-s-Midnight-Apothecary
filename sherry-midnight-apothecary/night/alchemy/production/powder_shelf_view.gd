class_name PowderShelfView
extends Control

@export var flour_texture: Texture2D
@export var paper_texture: Texture2D
@export_range(0.05, 2.0, 0.05) var placement_animation_seconds := 0.65

var shelf_state: PowderShelfState
var placement_tween: Tween

@onready var item_grid: GridContainer = %ItemGrid
@onready var empty_label: Label = %EmptyLabel


func setup(state: PowderShelfState) -> void:
	if shelf_state != null and shelf_state.changed.is_connected(refresh):
		shelf_state.changed.disconnect(refresh)
	shelf_state = state
	if shelf_state != null:
		shelf_state.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if item_grid == null:
		return
	for child: Node in item_grid.get_children():
		child.queue_free()
	if shelf_state == null:
		empty_label.visible = true
		return
	for powder: PowderInstanceData in shelf_state.items:
		var item := PowderItemView.new()
		item.custom_minimum_size = Vector2(105, 72)
		item.setup(powder, flour_texture, paper_texture)
		item_grid.add_child(item)
	empty_label.visible = shelf_state.items.is_empty()


func animate_item_from(instance_id: StringName, start_global_rect: Rect2) -> bool:
	var item := _find_item(instance_id)
	if item == null or start_global_rect.size.x <= 0.0 or start_global_rect.size.y <= 0.0:
		return false
	# Hide the destination until the grid has completed its layout. This avoids
	# a one-frame flash in the shelf before the package begins moving.
	item.visible = false
	call_deferred("_start_placement_animation", item, start_global_rect)
	return true


func _find_item(instance_id: StringName) -> PowderItemView:
	if item_grid == null:
		return null
	for child: Node in item_grid.get_children():
		var item := child as PowderItemView
		if item != null and item.powder != null and item.powder.source_instance_id == instance_id:
			return item
	return null


func _start_placement_animation(item: PowderItemView, start_global_rect: Rect2) -> void:
	if not is_instance_valid(item) or item.get_parent() == null:
		return
	var target_position := item.position
	var target_size := item.size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		call_deferred("_start_placement_animation", item, start_global_rect)
		return
	var parent_control := item.get_parent() as Control
	if parent_control == null:
		return
	var start_position := parent_control.get_global_transform().affine_inverse() * start_global_rect.position
	var target_global_size := item.get_global_rect().size
	var start_scale := Vector2(
		start_global_rect.size.x / maxf(target_global_size.x, 1.0),
		start_global_rect.size.y / maxf(target_global_size.y, 1.0)
	)
	if placement_tween != null and placement_tween.is_running():
		placement_tween.kill()
	item.pivot_offset = Vector2.ZERO
	item.position = start_position
	item.scale = start_scale
	item.modulate.a = 0.82
	item.z_index = 50
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.visible = true
	placement_tween = create_tween().set_parallel(true)
	placement_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	placement_tween.tween_property(item, "position", target_position, placement_animation_seconds)
	placement_tween.tween_property(item, "scale", Vector2.ONE, placement_animation_seconds)
	placement_tween.tween_property(item, "modulate:a", 1.0, placement_animation_seconds)
	placement_tween.finished.connect(_finish_placement_animation.bind(item))


func _finish_placement_animation(item: PowderItemView) -> void:
	if not is_instance_valid(item):
		return
	item.scale = Vector2.ONE
	item.modulate.a = 1.0
	item.z_index = 0
	item.mouse_filter = Control.MOUSE_FILTER_STOP
