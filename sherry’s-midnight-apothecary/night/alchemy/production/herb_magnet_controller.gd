class_name HerbMagnetController
extends Node

enum GrabMode { SINGLE, MULTI_MAGNET }
enum MultiGrabState { IDLE, HOLD_PENDING, COLLECTING, DRAGGING }
# Kept as an alias for older board integrations and scene tooling.
enum MagnetState { IDLE, SEARCHING, SNAPPING, DRAGGING }

@export_range(0.0, 80.0) var single_pick_radius := 20.0
@export_range(0.0, 50.0) var hover_assist_radius := 12.0
@export_range(0.0, 0.5) var long_press_duration := 0.12
@export_range(10.0, 250.0) var multi_capture_radius := 72.0
@export_range(0.0, 0.3) var multi_snap_duration := 0.08
@export var show_magnet_radius := true
# Legacy tuning names are retained for serialized scenes and older callers.
@export_range(0.0, 200.0) var candidate_radius := 72.0
@export_range(0.0, 150.0) var acquire_radius := 42.0
@export_range(0.0, 0.3) var candidate_hold_time := 0.05
@export_range(0.0, 0.3) var snap_duration := 0.08

var grab_mode: GrabMode = GrabMode.SINGLE
var multi_state: MultiGrabState = MultiGrabState.IDLE
var pointer_global := Vector2.ZERO
var hovered_piece: ProductionPieceView
var single_dragged_piece: ProductionPieceView
var grabbed_pieces: Array[ProductionPieceView] = []
var grabbed_piece_states: Dictionary = {}
var grabbed_piece_ids: Dictionary = {}
var candidate_piece: ProductionPieceView
var locked_piece: ProductionPieceView

# Compatibility properties used by the existing ProcessBoard.
var state: MagnetState:
	get:
		if _legacy_searching:
			return MagnetState.SNAPPING if locked_piece != null else MagnetState.SEARCHING
		if multi_state == MultiGrabState.IDLE and single_dragged_piece == null:
			return MagnetState.IDLE
		if multi_state == MultiGrabState.HOLD_PENDING:
			return MagnetState.SEARCHING
		if multi_state == MultiGrabState.COLLECTING:
			return MagnetState.SNAPPING
		return MagnetState.DRAGGING

var _board: ProcessBoard
var _hold_elapsed := 0.0
var _operation_serial := 0
var _recent_operations: Dictionary = {}
var _legacy_searching := false
var _legacy_elapsed := 0.0


func _ready() -> void:
	_board = get_parent() as ProcessBoard
	set_process(true)


func _process(delta: float) -> void:
	if _board == null or not _board.is_visible_in_tree():
		cancel_current_grab()
		return
	if grab_mode == GrabMode.MULTI_MAGNET and multi_state == MultiGrabState.HOLD_PENDING:
		_hold_elapsed += delta
		if _hold_elapsed >= long_press_duration:
			multi_state = MultiGrabState.COLLECTING
			collect_multi_candidates()
			if not grabbed_pieces.is_empty():
				multi_state = MultiGrabState.DRAGGING
			_board.queue_redraw()
	elif grab_mode == GrabMode.MULTI_MAGNET and multi_state in [MultiGrabState.COLLECTING, MultiGrabState.DRAGGING]:
		collect_multi_candidates()
		update_multi_drag()
	if _legacy_searching:
		advance(delta)


func handle_board_input(event: InputEvent) -> bool:
	if _board == null:
		return false
	if event is InputEventMouseMotion:
		update_pointer(_board.get_global_transform() * (event as InputEventMouseMotion).position)
		return single_dragged_piece != null or multi_state != MultiGrabState.IDLE
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		var global_point := _board.get_global_transform() * button.position
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				if not _board.get_movement_rect().has_point(global_point):
					return false
				pointer_global = global_point
				if grab_mode == GrabMode.SINGLE:
					var candidate := find_best_single_candidate(global_point)
					if candidate == null:
						return false
					begin_single_drag(candidate)
					return true
				begin_multi_hold()
				return true
			if single_dragged_piece != null:
				release_single_drag()
				return true
			if multi_state != MultiGrabState.IDLE:
				release_multi_grab()
				return true
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and (single_dragged_piece != null or multi_state != MultiGrabState.IDLE):
			cancel_current_grab()
			return true
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE and (single_dragged_piece != null or multi_state != MultiGrabState.IDLE):
			cancel_current_grab()
			return true
	return false


func update_pointer(global_point: Vector2) -> void:
	pointer_global = global_point
	if single_dragged_piece != null:
		update_single_drag()
	elif grab_mode == GrabMode.MULTI_MAGNET and multi_state in [MultiGrabState.COLLECTING, MultiGrabState.DRAGGING]:
		collect_multi_candidates()
		update_multi_drag()
	elif grab_mode == GrabMode.SINGLE:
		_update_hover()
	if _board != null:
		_board.queue_redraw()


func set_grab_mode(mode: GrabMode) -> void:
	if grab_mode == mode:
		return
	if single_dragged_piece != null or multi_state != MultiGrabState.IDLE:
		cancel_current_grab()
	grab_mode = mode
	_clear_hover()


func begin_search(global_point: Vector2) -> bool:
	if _board == null or not _board.get_movement_rect().has_point(global_point):
		return false
	cancel_current_grab()
	pointer_global = global_point
	candidate_piece = _find_best_candidate(global_point, candidate_radius)
	_legacy_searching = true
	_legacy_elapsed = 0.0
	if candidate_piece != null and candidate_piece.contains_global_point(global_point):
		_begin_legacy_drag()
	return true


func advance(delta: float) -> void:
	if not _legacy_searching or locked_piece != null:
		return
	_legacy_elapsed += maxf(delta, 0.0)
	if candidate_piece != null and _legacy_elapsed >= candidate_hold_time:
		_begin_legacy_drag()


func _begin_legacy_drag() -> void:
	if candidate_piece == null:
		return
	begin_single_drag(candidate_piece)
	locked_piece = single_dragged_piece


func release_piece() -> void:
	if locked_piece != null:
		release_single_drag()
	locked_piece = null
	candidate_piece = null
	_legacy_searching = false


func cancel_interaction() -> void:
	cancel_current_grab()
	locked_piece = null
	candidate_piece = null
	_legacy_searching = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		cancel_interaction()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		cancel_interaction()


func find_best_single_candidate(cursor_global: Vector2) -> ProductionPieceView:
	return _find_best_candidate(cursor_global, single_pick_radius)


func find_best_candidate(cursor_global: Vector2) -> ProductionPieceView:
	return _find_best_candidate(cursor_global, hover_assist_radius)


func _find_best_candidate(cursor_global: Vector2, assist_radius: float) -> ProductionPieceView:
	if _board == null:
		return null
	var best: ProductionPieceView
	var best_direct := false
	var best_distance := INF
	for view: ProductionPieceView in _board.get_piece_views():
		if not view.is_movable():
			continue
		var direct := view.contains_global_point(cursor_global)
		var distance := 0.0 if direct else view.distance_to_interaction_area(cursor_global)
		if not direct and distance > assist_radius:
			continue
		if best == null or (direct and not best_direct) or (direct == best_direct and (distance < best_distance or (is_equal_approx(distance, best_distance) and _sorts_above(view, best)))):
			best = view
			best_direct = direct
			best_distance = distance
	return best


func _sorts_above(left: ProductionPieceView, right: ProductionPieceView) -> bool:
	return left.z_index > right.z_index or (left.z_index == right.z_index and int(_recent_operations.get(left, 0)) > int(_recent_operations.get(right, 0)))


func begin_single_drag(piece: ProductionPieceView) -> void:
	if piece == null or not piece.is_movable():
		return
	single_dragged_piece = piece
	piece._begin_drag_at(pointer_global)
	piece.set_outline_state(ProductionPieceView.OutlineState.GRABBED)


func update_single_drag() -> void:
	if is_instance_valid(single_dragged_piece):
		_board.move_piece_view(single_dragged_piece, pointer_global - single_dragged_piece.drag_grab_offset)


func release_single_drag() -> void:
	if is_instance_valid(single_dragged_piece):
		single_dragged_piece._end_drag()
		_mark_recent(single_dragged_piece)
	single_dragged_piece = null
	_update_hover()


func begin_multi_hold() -> void:
	cancel_current_grab()
	multi_state = MultiGrabState.HOLD_PENDING
	_hold_elapsed = 0.0


func find_all_multi_candidates(cursor_global: Vector2) -> Array[ProductionPieceView]:
	var result: Array[ProductionPieceView] = []
	if _board == null:
		return result
	for view: ProductionPieceView in _board.get_piece_views():
		if view.is_movable() and (view.contains_global_point(cursor_global) or view.distance_to_interaction_area(cursor_global) <= multi_capture_radius):
			result.append(view)
	return result


func collect_multi_candidates() -> void:
	for piece: ProductionPieceView in find_all_multi_candidates(pointer_global):
		if not grabbed_piece_ids.has(piece):
			add_piece_to_multi_grab(piece)


func add_piece_to_multi_grab(piece: ProductionPieceView) -> void:
	if piece == null or grabbed_piece_ids.has(piece) or not piece.is_movable():
		return
	grabbed_piece_ids[piece] = true
	grabbed_pieces.append(piece)
	grabbed_piece_states[piece] = {
		"cursor_offset": (piece.global_position - pointer_global) * 0.85,
		"snap_start_offset": piece.global_position - pointer_global,
		"snap_elapsed": 0.0,
		"original_global_position": piece.global_position,
		"original_state": piece.piece.state,
		"original_z_index": piece.z_index,
	}
	_board.raise_piece_view(piece)
	piece.is_dragging = true
	piece.set_outline_state(ProductionPieceView.OutlineState.GRABBED)


func update_multi_drag() -> void:
	for piece: ProductionPieceView in grabbed_pieces:
		if is_instance_valid(piece):
			var record: Dictionary = grabbed_piece_states.get(piece, {})
			var elapsed := float(record.get("snap_elapsed", 0.0))
			elapsed += get_process_delta_time()
			record["snap_elapsed"] = elapsed
			grabbed_piece_states[piece] = record
			var t := 1.0 if multi_snap_duration <= 0.0 else clampf(elapsed / multi_snap_duration, 0.0, 1.0)
			var offset: Vector2 = record.get("snap_start_offset", Vector2.ZERO).lerp(record.get("cursor_offset", Vector2.ZERO), ease(t, -2.0))
			_board.move_piece_view(piece, pointer_global + offset)


func release_multi_grab() -> void:
	for piece: ProductionPieceView in grabbed_pieces:
		if is_instance_valid(piece):
			piece.is_dragging = false
			piece.refresh_state_visual()
			_board.finish_piece_drag(piece)
			_mark_recent(piece)
	_clear_multi_state()


func cancel_current_grab() -> void:
	if is_instance_valid(single_dragged_piece):
		_board.move_piece_view(single_dragged_piece, single_dragged_piece.drag_start_position)
		single_dragged_piece.force_cancel_drag()
	single_dragged_piece = null
	for piece: ProductionPieceView in grabbed_pieces:
		if is_instance_valid(piece):
			var record: Dictionary = grabbed_piece_states.get(piece, {})
			_board.move_piece_view(piece, record.get("original_global_position", piece.global_position))
			piece.piece.state = record.get("original_state", piece.piece.state)
			piece.z_index = int(record.get("original_z_index", piece.z_index))
			piece.restore_after_magnet_cancel()
	_clear_multi_state()
	_clear_hover()


func _clear_multi_state() -> void:
	grabbed_pieces.clear()
	grabbed_piece_states.clear()
	grabbed_piece_ids.clear()
	multi_state = MultiGrabState.IDLE
	_hold_elapsed = 0.0
	if _board != null:
		_board.queue_redraw()


func should_draw_radius() -> bool:
	return show_magnet_radius and multi_state in [MultiGrabState.COLLECTING, MultiGrabState.DRAGGING]


func clear_hover() -> void:
	_clear_hover()


func _update_hover() -> void:
	var next := _find_best_candidate(pointer_global, hover_assist_radius)
	if next == hovered_piece:
		return
	_clear_hover()
	hovered_piece = next
	if is_instance_valid(hovered_piece):
		hovered_piece.set_outline_state(ProductionPieceView.OutlineState.HOVER)


func _clear_hover() -> void:
	if is_instance_valid(hovered_piece) and hovered_piece not in grabbed_pieces:
		hovered_piece.set_outline_state(ProductionPieceView.OutlineState.NONE)
	hovered_piece = null


func _mark_recent(view: ProductionPieceView) -> void:
	_operation_serial += 1
	_recent_operations[view] = _operation_serial
