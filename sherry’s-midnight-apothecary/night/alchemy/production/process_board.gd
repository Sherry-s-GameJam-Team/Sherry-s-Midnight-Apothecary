class_name ProcessBoard
extends PanelContainer

signal herb_dropped(ingredient_id: StringName)
signal piece_moved(piece: ProductionRuntimeTypes.HerbPieceRuntime, target_state: int)

enum PieceRegion {
	WORKBENCH,
	WASTE,
	GRIND,
}

const BOARD_START_RATIO := 0.28
const BOARD_END_RATIO := 0.80

@export var waste_detection_margin := Vector4(35.0, 35.0, 35.0, 35.0)
@export var grind_detection_margin := Vector4(35.0, 35.0, 35.0, 35.0)
@export_range(0.0, 1.0) var zone_overlap_threshold := 0.25

var piece_stack_serial := 100
var _piece_views: Dictionary = {}
var _current_herb: IngredientData

@onready var whole_herb_label: Label = %WholeHerbLabel
@onready var board_items: HFlowContainer = %BoardItems
@onready var zones: Control = $Sprite2D/Zones
@onready var waste_zone: Control = $Sprite2D/Zones/WasteZone
@onready var board_zone: Control = $Sprite2D/Zones/BoardZone
@onready var grind_zone: Control = $Sprite2D/Zones/GrindZone
@onready var piece_movement_bounds: Control = %PieceMovementBounds
@onready var piece_drag_layer: Control = %PieceDragLayer
@onready var magnet_controller: HerbMagnetController = $MagnetController


func _gui_input(event: InputEvent) -> void:
	if magnet_controller != null and magnet_controller.handle_board_input(event):
		accept_event()


func _draw() -> void:
	if magnet_controller == null or not magnet_controller.should_draw_radius():
		return
	var local_pointer := get_global_transform().affine_inverse() * magnet_controller.pointer_global
	var global_scale := get_global_transform().get_scale().abs()
	var local_radius := magnet_controller.multi_capture_radius / maxf(minf(global_scale.x, global_scale.y), 0.001)
	var fill := Color(0.96, 0.82, 0.38, 0.055)
	var rim := Color(1.0, 0.88, 0.5, 0.28)
	draw_circle(local_pointer, local_radius, fill)
	draw_arc(local_pointer, local_radius, 0.0, TAU, 48, rim, 1.2, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and magnet_controller != null and magnet_controller.state == HerbMagnetController.MagnetState.IDLE:
		magnet_controller.clear_hover()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and magnet_controller != null:
		magnet_controller.cancel_interaction()


func _can_drop_data(position: Vector2, data: Variant) -> bool:
	if data is not Dictionary:
		return false
	if data.get("kind") == &"herb_piece":
		return true
	if data.get("kind") != &"herb":
		return false
	var ratio := position.x / maxf(size.x, 1.0)
	return ratio >= BOARD_START_RATIO and ratio <= BOARD_END_RATIO


func _drop_data(position: Vector2, data: Variant) -> void:
	if data is not Dictionary:
		return
	if data.get("kind") == &"herb":
		var herb_ratio := position.x / maxf(size.x, 1.0)
		if herb_ratio >= BOARD_START_RATIO and herb_ratio <= BOARD_END_RATIO:
			herb_dropped.emit(StringName(str(data.get("ingredient_id", ""))))
		return
	var piece := data.get("piece") as ProductionRuntimeTypes.HerbPieceRuntime
	var view := get_piece_view(piece)
	if view == null:
		return
	var target_global := get_global_transform() * position
	_move_piece_view(view, target_global - view.size * 0.5)
	_apply_piece_region(view, classify_piece_region(view))


func show_state(whole_herb: IngredientData, pieces: Array[ProductionRuntimeTypes.HerbPieceRuntime]) -> void:
	if magnet_controller != null and magnet_controller.state != HerbMagnetController.MagnetState.IDLE:
		magnet_controller.cancel_interaction()
	_current_herb = whole_herb
	_clear_container(board_items)
	var attached_groups: Dictionary = {}
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state != ProductionRuntimeTypes.HerbPieceRuntime.State.ATTACHED:
			continue
		var source_id := piece.source_instance_id
		if not attached_groups.has(source_id):
			attached_groups[source_id] = []
		var source_pieces: Array = attached_groups[source_id]
		source_pieces.append(piece)
		attached_groups[source_id] = source_pieces
	for source_id: Variant in attached_groups:
		var untyped_group: Array = attached_groups[source_id]
		var source_pieces: Array[ProductionRuntimeTypes.HerbPieceRuntime] = []
		source_pieces.assign(untyped_group)
		if source_pieces.is_empty():
			continue
		var source_herb := source_pieces[0].source_ingredient
		if source_herb == null:
			source_herb = whole_herb
		var assembly := HerbAssemblyView.new()
		assembly.custom_minimum_size = Vector2(350, 142)
		assembly.setup(source_herb, source_pieces)
		if assembly.has_visual_pieces():
			board_items.add_child(assembly)
		else:
			assembly.queue_free()
	whole_herb_label.text = "拖入药材"
	whole_herb_label.visible = pieces.is_empty()
	_sync_piece_views(whole_herb, pieces)


func _sync_piece_views(whole_herb: IngredientData, pieces: Array[ProductionRuntimeTypes.HerbPieceRuntime]) -> void:
	var active: Dictionary = {}
	for piece: ProductionRuntimeTypes.HerbPieceRuntime in pieces:
		if piece.state in [
			ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED,
			ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE,
			ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND,
		]:
			active[piece] = true
	for existing_piece: Variant in _piece_views.keys():
		if not active.has(existing_piece):
			var old_view := _piece_views[existing_piece] as ProductionPieceView
			_piece_views.erase(existing_piece)
			if is_instance_valid(old_view):
				old_view.force_cancel_drag()
				old_view.queue_free()
	for index: int in pieces.size():
		var piece := pieces[index]
		if not active.has(piece):
			continue
		var view := get_piece_view(piece)
		if view == null:
			view = ProductionPieceView.new()
			var source_herb := piece.source_ingredient if piece.source_ingredient != null else whole_herb
			view.setup(piece, _piece_display_size(piece, source_herb))
			view.drag_started.connect(_on_piece_drag_started)
			view.drag_position_requested.connect(_on_piece_drag_position_requested)
			view.drag_finished.connect(_on_piece_drag_finished)
			piece_drag_layer.add_child(view)
			_piece_views[piece] = view
			if piece.has_workspace_position:
				view.position = piece.workspace_position
			else:
				view.position = _initial_piece_position(piece, source_herb, index, view.size)
				piece.workspace_position = view.position
				piece.has_workspace_position = true
			piece.stack_z = piece.data.z_order if piece.stack_z == 0 else piece.stack_z
			view.z_index = piece.stack_z
		view.visible = true
		view.refresh_state_visual()


func get_piece_view(piece: ProductionRuntimeTypes.HerbPieceRuntime) -> ProductionPieceView:
	if piece == null or not _piece_views.has(piece):
		return null
	var view := _piece_views[piece] as ProductionPieceView
	return view if is_instance_valid(view) else null


func get_piece_views() -> Array[ProductionPieceView]:
	var result: Array[ProductionPieceView] = []
	for value: Variant in _piece_views.values():
		var view := value as ProductionPieceView
		if is_instance_valid(view):
			result.append(view)
	return result


func update_piece_visual(piece: ProductionRuntimeTypes.HerbPieceRuntime) -> void:
	var view := get_piece_view(piece)
	if view != null:
		view.refresh_state_visual()


func reclassify_movable_pieces() -> void:
	for view: ProductionPieceView in get_piece_views():
		if view.piece.state in [
			ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED,
			ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE,
			ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND,
		]:
			_apply_piece_region(view, classify_piece_region(view))


func formalize_waste() -> void:
	reclassify_movable_pieces()
	for view: ProductionPieceView in get_piece_views():
		if view.piece.state == ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE:
			view.piece.state = ProductionRuntimeTypes.HerbPieceRuntime.State.DISCARDED
			_piece_views.erase(view.piece)
			view.force_cancel_drag()
			view.queue_free()


func classify_piece_region(view: ProductionPieceView) -> int:
	if view == null:
		return PieceRegion.WORKBENCH
	var piece_rect := get_global_content_rect(view)
	if piece_rect.size.x <= 0.0 or piece_rect.size.y <= 0.0:
		return PieceRegion.WORKBENCH
	var center := piece_rect.get_center()
	var grind_rect := get_grind_detection_rect()
	var waste_rect := get_waste_detection_rect()
	var center_in_grind := grind_rect.has_point(center)
	var center_in_waste := waste_rect.has_point(center)
	var grind_ratio := _overlap_ratio(piece_rect, grind_rect)
	var waste_ratio := _overlap_ratio(piece_rect, waste_rect)
	if center_in_grind and not center_in_waste:
		return PieceRegion.GRIND
	if center_in_waste and not center_in_grind:
		return PieceRegion.WASTE
	if center_in_grind and center_in_waste:
		return PieceRegion.GRIND if grind_ratio >= waste_ratio else PieceRegion.WASTE
	var grind_hit := grind_ratio >= zone_overlap_threshold
	var waste_hit := waste_ratio >= zone_overlap_threshold
	if grind_hit and not waste_hit:
		return PieceRegion.GRIND
	if waste_hit and not grind_hit:
		return PieceRegion.WASTE
	if grind_hit and waste_hit:
		if not is_equal_approx(grind_ratio, waste_ratio):
			return PieceRegion.GRIND if grind_ratio > waste_ratio else PieceRegion.WASTE
		return _region_from_piece_state(view.piece.state)
	return PieceRegion.WORKBENCH


func get_waste_detection_rect() -> Rect2:
	return _expanded_rect(get_global_control_rect(waste_zone), waste_detection_margin)


func get_grind_detection_rect() -> Rect2:
	return _expanded_rect(get_global_control_rect(grind_zone), grind_detection_margin)


func get_movement_rect() -> Rect2:
	return get_global_control_rect(piece_movement_bounds)


func get_global_content_rect(view: ProductionPieceView) -> Rect2:
	return _global_rect_from_local(view, view.get_local_content_rect())


func get_global_control_rect(control: Control) -> Rect2:
	return _global_rect_from_local(control, Rect2(Vector2.ZERO, control.size))


func _global_rect_from_local(control: Control, local_rect: Rect2) -> Rect2:
	var transform := control.get_global_transform()
	var points: Array[Vector2] = [
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var result := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		result = result.expand(point)
	return result


func _expanded_rect(rect: Rect2, margin: Vector4) -> Rect2:
	return Rect2(
		rect.position - Vector2(margin.x, margin.y),
		rect.size + Vector2(margin.x + margin.z, margin.y + margin.w)
	)


func _overlap_ratio(piece_rect: Rect2, zone_rect: Rect2) -> float:
	var area := piece_rect.size.x * piece_rect.size.y
	if area <= 0.0 or not piece_rect.intersects(zone_rect):
		return 0.0
	var overlap := piece_rect.intersection(zone_rect)
	return clampf((overlap.size.x * overlap.size.y) / area, 0.0, 1.0)


func _region_from_piece_state(state: int) -> int:
	match state:
		ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND:
			return PieceRegion.GRIND
		ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE:
			return PieceRegion.WASTE
		_:
			return PieceRegion.WORKBENCH


func _apply_piece_region(view: ProductionPieceView, region: int) -> void:
	if view == null or view.piece == null:
		return
	var target_state := ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED
	if region == PieceRegion.GRIND and view.piece.data.grindable:
		target_state = ProductionRuntimeTypes.HerbPieceRuntime.State.GRIND
	elif region == PieceRegion.WASTE:
		target_state = ProductionRuntimeTypes.HerbPieceRuntime.State.WASTE
	if view.piece.state != target_state:
		view.piece.state = target_state
		piece_moved.emit(view.piece, target_state)
	view.refresh_state_visual()


func _on_piece_drag_started(view: ProductionPieceView) -> void:
	if view.get_parent() != piece_drag_layer:
		view.reparent(piece_drag_layer, true)
	piece_stack_serial += 1
	view.z_index = piece_stack_serial
	view.piece.stack_z = piece_stack_serial


func _on_piece_drag_position_requested(view: ProductionPieceView, desired_global_position: Vector2) -> void:
	_move_piece_view(view, desired_global_position)


func _on_piece_drag_finished(view: ProductionPieceView) -> void:
	if view == null:
		return
	view.piece.workspace_position = view.position
	view.piece.has_workspace_position = true
	_apply_piece_region(view, classify_piece_region(view))


func _move_piece_view(view: ProductionPieceView, desired_global_position: Vector2) -> void:
	if view == null:
		return
	view.global_position = desired_global_position
	var movement_rect := get_movement_rect()
	var content_rect := get_global_content_rect(view)
	var clamped_center := Vector2(
		clampf(content_rect.get_center().x, movement_rect.position.x, movement_rect.end.x),
		clampf(content_rect.get_center().y, movement_rect.position.y, movement_rect.end.y)
	)
	view.global_position += clamped_center - content_rect.get_center()
	view.piece.workspace_position = view.position
	view.piece.has_workspace_position = true


func move_piece_view(view: ProductionPieceView, desired_global_position: Vector2) -> void:
	_move_piece_view(view, desired_global_position)


func raise_piece_view(view: ProductionPieceView) -> void:
	if view == null:
		return
	piece_stack_serial += 1
	view.z_index = piece_stack_serial
	view.piece.stack_z = piece_stack_serial


func finish_piece_drag(view: ProductionPieceView) -> void:
	_on_piece_drag_finished(view)


func _piece_display_size(piece: ProductionRuntimeTypes.HerbPieceRuntime, herb: IngredientData) -> Vector2:
	if piece == null or piece.data == null or piece.data.texture == null:
		return Vector2(48.0, 48.0)
	var source_size := Vector2(piece.data.source_rect.size)
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		source_size = Vector2(piece.data.texture.get_size())
	var reference := Vector2(herb.reference_canvas_size) if herb != null else Vector2.ZERO
	var board_size := get_global_control_rect(board_zone).size
	var scale_factor := minf(board_size.x / maxf(reference.x, 1.0), board_size.y / maxf(reference.y, 1.0))
	var content_size := source_size * scale_factor
	var longest := maxf(content_size.x, content_size.y)
	var target_longest := clampf(longest, 34.0, 74.0)
	content_size *= target_longest / maxf(longest, 1.0)
	return content_size + Vector2.ONE * ProductionPieceView.VISUAL_PADDING * 2.0


func _initial_piece_position(
	piece: ProductionRuntimeTypes.HerbPieceRuntime,
	herb: IngredientData,
	index: int,
	view_size: Vector2
) -> Vector2:
	var board_rect := get_global_control_rect(board_zone)
	var normalized_center := Vector2(0.5, 0.5)
	if herb != null and herb.reference_canvas_size.x > 0 and herb.reference_canvas_size.y > 0 and piece.data.source_rect.size != Vector2i.ZERO:
		normalized_center = Vector2(piece.data.source_rect.get_center()) / Vector2(herb.reference_canvas_size)
	var center_global := board_rect.position + normalized_center * board_rect.size
	var angle := float(index) * 2.399963
	var radius := 8.0 + float(index % 4) * 4.0
	center_global += Vector2(cos(angle), sin(angle)) * radius
	var local_center: Vector2 = piece_drag_layer.get_global_transform().affine_inverse() * center_global
	var position: Vector2 = local_center - view_size * 0.5
	var local_bounds := Rect2(Vector2.ZERO, piece_drag_layer.size)
	position.x = clampf(position.x, local_bounds.position.x - view_size.x * 0.5, local_bounds.end.x - view_size.x * 0.5)
	position.y = clampf(position.y, local_bounds.position.y - view_size.y * 0.5, local_bounds.end.y - view_size.y * 0.5)
	return position


func _clear_piece_views() -> void:
	for view: ProductionPieceView in get_piece_views():
		view.force_cancel_drag()
		view.queue_free()
	_piece_views.clear()


func cancel_active_drags() -> void:
	if magnet_controller != null:
		magnet_controller.cancel_interaction()
	for view: ProductionPieceView in get_piece_views():
		var was_dragging := view.is_dragging
		view.force_cancel_drag()
		if was_dragging:
			_apply_piece_region(view, classify_piece_region(view))


func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
