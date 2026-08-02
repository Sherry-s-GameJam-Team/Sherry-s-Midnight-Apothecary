extends SceneTree

const ALCHEMY_SCENE := preload("res://night/alchemy/alchemy_runtime.tscn")
const HERB_ID := &"herdsmans_loaf_bush"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := ALCHEMY_SCENE.instantiate() as AlchemyRuntime
	root.add_child(runtime)
	var player := PlayerData.new()
	player.inventory = {HERB_ID: 1}
	runtime.setup(player, NightResult.new(), 1)
	var panel := runtime.production_panel
	panel._on_herb_dropped(HERB_ID)
	_check(panel.separate_herb(), "Herb pieces can be separated for interaction testing.")
	await process_frame
	var board := panel.process_board
	var controller := board.magnet_controller
	var views := board.get_piece_views()
	_check(views.size() >= 2, "The test herb provides multiple movable pieces.")
	if views.size() < 2:
		runtime.free()
		quit(1)
		return
	var first := views[0]
	var second := views[1]
	var origin := board.get_global_control_rect(board.board_zone).get_center()
	board.move_piece_view(first, origin - first.size * 0.5)
	board.move_piece_view(second, origin + Vector2(14.0, 4.0) - second.size * 0.5)
	controller.set_grab_mode(HerbMagnetController.GrabMode.MULTI_MAGNET)
	_send_left(controller, board, origin, true)
	_check(controller.multi_state == HerbMagnetController.MultiGrabState.HOLD_PENDING, "Multi mode begins in HOLD_PENDING.")
	controller._process(controller.long_press_duration + 0.02)
	_check(controller.grabbed_pieces.size() >= 2, "Long press captures every nearby movable piece.")
	_check(controller.should_draw_radius(), "Capture radius becomes visible after long press.")
	var moved_cursor := origin + Vector2(32.0, 11.0)
	controller.update_pointer(moved_cursor)
	_check(not first.global_position.is_equal_approx(origin - first.size * 0.5), "Captured pieces follow the cursor.")
	_send_left(controller, board, moved_cursor, false)
	_check(controller.grabbed_pieces.is_empty() and controller.multi_state == HerbMagnetController.MultiGrabState.IDLE, "Release clears the complete multi-grab set.")

	var cancellation_origin := first.global_position
	_send_left(controller, board, first.get_global_content_rect().get_center(), true)
	controller._process(controller.long_press_duration + 0.02)
	controller.update_pointer(origin + Vector2(90.0, 0.0))
	controller.cancel_current_grab()
	_check(first.global_position.is_equal_approx(cancellation_origin), "Cancel restores each captured piece position.")

	controller.set_grab_mode(HerbMagnetController.GrabMode.SINGLE)
	_send_left(controller, board, second.get_global_content_rect().get_center(), true)
	_check(controller.single_dragged_piece == second, "Single mode selects exactly one best candidate.")
	_send_left(controller, board, second.get_global_content_rect().get_center(), false)
	_check(controller.single_dragged_piece == null, "Single release only releases the selected piece.")
	runtime.free()
	if _failures == 0:
		print("Herb interaction controller regression test passed.")
		quit(0)
	else:
		quit(1)


func _send_left(controller: HerbMagnetController, board: ProcessBoard, global_point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = board.get_global_transform().affine_inverse() * global_point
	controller.handle_board_input(event)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
