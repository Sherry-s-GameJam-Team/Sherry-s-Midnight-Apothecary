class_name HerbMagnetController
extends Node

enum MagnetState {
	IDLE,
	SEARCHING,
	SNAPPING,
	DRAGGING,
}

@export_range(0.0, 200.0) var candidate_radius := 72.0
@export_range(0.0, 150.0) var acquire_radius := 42.0
@export_range(0.0, 0.3) var candidate_hold_time := 0.05
@export_range(0.0, 0.3) var snap_duration := 0.08
@export var direct_hit_immediate := true
@export var show_magnet_radius := true

var state := MagnetState.IDLE
var candidate_piece: ProductionPieceView
var locked_piece: ProductionPieceView
var pointer_global := Vector2.ZERO
var snap_elapsed := 0.0
var snap_start_offset := Vector2.ZERO
var drag_start_global_position := Vector2.ZERO
var drag_start_state := ProductionRuntimeTypes.HerbPieceRuntime.State.SEPARATED

var _board: ProcessBoard
var _hover_piece: ProductionPieceView
var _candidate_hold_elapsed := 0.0
var _operation_serial := 0
var _recent_operations: Dictionary = {}


func _ready() -> void:
	_board = get_parent() as ProcessBoard
	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	if _board == null or not _board.is_visible_in_tree():
		if state != MagnetState.IDLE:
			cancel_interaction()
		return
	advance(delta)


func _input(event: InputEvent) -> void:
	if state == MagnetState.IDLE:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			cancel_interaction()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			cancel_interaction()
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			pointer_global = _board.get_global_mouse_position()
			release_piece()
			get_viewport().set_input_as_handled()


func handle_board_input(event: InputEvent) -> bool:
	if _board == null:
		return false
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		update_pointer(_board.get_global_transform() * motion.position)
		return state != MagnetState.IDLE
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var global_point := _board.get_global_transform() * button.position
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				return begin_search(global_point)
			if state != MagnetState.IDLE:
				pointer_global = global_point
				release_piece()
				return true
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and state != MagnetState.IDLE:
			cancel_interaction()
			return true
	return false


func begin_search(global_point: Vector2) -> bool:
	if _board == null or not _board.get_movement_rect().has_point(global_point):
		return false
	cancel_interaction()
	pointer_global = global_point
	state = MagnetState.SEARCHING
	_clear_hover()
	_update_candidate(0.0)
	_board.queue_redraw()
	return true


func update_pointer(global_point: Vector2) -> void:
	pointer_global = global_point
	match state:
		MagnetState.IDLE:
			_update_idle_hover()
		MagnetState.SEARCHING:
			_update_candidate(0.0)
		MagnetState.SNAPPING:
			_advance_snap(0.0)
		MagnetState.DRAGGING:
			_follow_pointer()
	if _board != null:
		_board.queue_redraw()


func advance(delta: float) -> void:
	match state:
		MagnetState.SEARCHING:
			_update_candidate(maxf(delta, 0.0))
		MagnetState.SNAPPING:
			_advance_snap(maxf(delta, 0.0))


func release_piece() -> void:
	if state == MagnetState.SEARCHING:
		_reset_to_idle()
		return
	if state not in [MagnetState.SNAPPING, MagnetState.DRAGGING]:
		return
	var released := locked_piece
	if is_instance_valid(released):
		released._end_drag()
		_mark_recent(released)
	_reset_to_idle()


func cancel_interaction() -> void:
	if state in [MagnetState.SNAPPING, MagnetState.DRAGGING] and is_instance_valid(locked_piece):
		_board.move_piece_view(locked_piece, drag_start_global_position)
		locked_piece.piece.state = drag_start_state
		locked_piece.piece.workspace_position = locked_piece.position
		locked_piece.piece.has_workspace_position = true
		locked_piece.restore_after_magnet_cancel()
		locked_piece.refresh_state_visual()
	_reset_to_idle()


func find_best_candidate(global_point: Vector2) -> ProductionPieceView:
	if _board == null:
		return null
	var best: ProductionPieceView
	var best_direct := false
	var best_distance := INF
	var scale_factor := _design_scale()
	var max_distance := candidate_radius * scale_factor
	var tie_distance := 0.5 * scale_factor
	for view: ProductionPieceView in _board.get_piece_views():
		if not view._is_piece_movable():
			continue
		var direct := view.contains_global_point(global_point)
		var distance := 0.0 if direct else distance_to_piece_rect(global_point, view)
		if not direct and distance > max_distance:
			continue
		if best == null:
			best = view
			best_direct = direct
			best_distance = distance
			continue
		if direct != best_direct:
			if direct:
				best = view
				best_direct = true
				best_distance = 0.0
			continue
		if distance < best_distance - tie_distance:
			best = view
			best_distance = distance
			continue
		if absf(distance - best_distance) <= tie_distance:
			if view.z_index > best.z_index or (
				view.z_index == best.z_index and _recent_rank(view) > _recent_rank(best)
			):
				best = view
				best_distance = distance
	return best


func distance_to_piece_rect(global_point: Vector2, view: ProductionPieceView) -> float:
	if view == null:
		return INF
	var rect := view.get_global_content_rect()
	var nearest := Vector2(
		clampf(global_point.x, rect.position.x, rect.end.x),
		clampf(global_point.y, rect.position.y, rect.end.y)
	)
	return global_point.distance_to(nearest)


func should_draw_radius() -> bool:
	return show_magnet_radius and state == MagnetState.SEARCHING


func clear_hover() -> void:
	_clear_hover()


func _update_candidate(delta: float) -> void:
	if state != MagnetState.SEARCHING:
		return
	var next_candidate := find_best_candidate(pointer_global)
	var direct_before_emphasis := next_candidate != null and next_candidate.contains_global_point(pointer_global)
	if next_candidate != candidate_piece:
		_set_candidate(next_candidate)
		_candidate_hold_elapsed = 0.0
	if candidate_piece == null:
		return
	var direct := direct_before_emphasis if next_candidate == candidate_piece else candidate_piece.contains_global_point(pointer_global)
	if direct and direct_hit_immediate:
		_begin_snap(candidate_piece)
		return
	var distance := distance_to_piece_rect(pointer_global, candidate_piece)
	if distance <= acquire_radius * _design_scale():
		_candidate_hold_elapsed += delta
		if _candidate_hold_elapsed >= candidate_hold_time:
			_begin_snap(candidate_piece)
	else:
		_candidate_hold_elapsed = 0.0


func _begin_snap(view: ProductionPieceView) -> void:
	if state != MagnetState.SEARCHING or not is_instance_valid(view) or not view._is_piece_movable():
		return
	locked_piece = view
	drag_start_global_position = view.global_position
	drag_start_state = view.piece.state
	view._begin_drag_at(view.global_position + view.get_scaled_pickup_anchor())
	snap_start_offset = view.global_position - pointer_global
	snap_elapsed = 0.0
	state = MagnetState.SNAPPING
	view.set_magnet_emphasis(true, true)
	if snap_duration <= 0.0:
		state = MagnetState.DRAGGING
		_follow_pointer()


func _advance_snap(delta: float) -> void:
	if state != MagnetState.SNAPPING or not is_instance_valid(locked_piece):
		return
	snap_elapsed += delta
	var t := 1.0 if snap_duration <= 0.0 else clampf(snap_elapsed / snap_duration, 0.0, 1.0)
	var eased_t := ease(t, -2.0)
	var target_offset := -locked_piece.get_scaled_pickup_anchor()
	var current_offset := snap_start_offset.lerp(target_offset, eased_t)
	_board.move_piece_view(locked_piece, pointer_global + current_offset)
	if t >= 1.0:
		state = MagnetState.DRAGGING


func _follow_pointer() -> void:
	if state != MagnetState.DRAGGING or not is_instance_valid(locked_piece):
		return
	_board.move_piece_view(locked_piece, pointer_global - locked_piece.get_scaled_pickup_anchor())


func _update_idle_hover() -> void:
	var next_hover := find_best_candidate(pointer_global)
	if next_hover != null and not next_hover.contains_global_point(pointer_global):
		next_hover = null
	if next_hover == _hover_piece:
		return
	_clear_hover()
	_hover_piece = next_hover
	if is_instance_valid(_hover_piece):
		_hover_piece.set_magnet_emphasis(true)


func _set_candidate(value: ProductionPieceView) -> void:
	if is_instance_valid(candidate_piece) and candidate_piece != value:
		candidate_piece.set_magnet_emphasis(false)
	candidate_piece = value
	if is_instance_valid(candidate_piece):
		candidate_piece.set_magnet_emphasis(true, true)


func _reset_to_idle() -> void:
	if is_instance_valid(candidate_piece):
		candidate_piece.set_magnet_emphasis(false)
	if is_instance_valid(locked_piece):
		locked_piece.set_magnet_emphasis(false)
	candidate_piece = null
	locked_piece = null
	_candidate_hold_elapsed = 0.0
	snap_elapsed = 0.0
	state = MagnetState.IDLE
	if _board != null:
		_board.queue_redraw()


func _clear_hover() -> void:
	if is_instance_valid(_hover_piece):
		_hover_piece.set_magnet_emphasis(false)
	_hover_piece = null


func _mark_recent(view: ProductionPieceView) -> void:
	_operation_serial += 1
	_recent_operations[view] = _operation_serial


func _recent_rank(view: ProductionPieceView) -> int:
	return int(_recent_operations.get(view, 0))


func _design_scale() -> float:
	if _board == null:
		return 1.0
	var global_scale := _board.get_global_transform().get_scale().abs()
	return maxf(minf(global_scale.x, global_scale.y), 0.001)
