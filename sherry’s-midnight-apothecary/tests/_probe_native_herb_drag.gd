extends SceneTree

const ALCHEMY_SCENE := preload("res://night/alchemy/alchemy_runtime.tscn")
const HERB_ID := &"herdsmans_loaf_bush"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := ALCHEMY_SCENE.instantiate() as AlchemyRuntime
	root.add_child(runtime)
	var player := PlayerData.new()
	player.inventory = {HERB_ID: 2}
	runtime.setup(player, NightResult.new(), 1)
	runtime.current_panel = AlchemyRuntime.PanelMode.PRODUCTION
	runtime.horizontal_stage.position.x = -runtime.production_panel.position.x
	runtime.unified_powder_shelf.anchor_left = 0.015
	runtime.unified_powder_shelf.anchor_right = 0.275
	await process_frame
	await process_frame
	var panel := runtime.production_panel
	var board := panel.process_board
	var card := panel.herb_grid.get_child(0) as Control
	var source := card.get_global_rect().get_center()
	var board_rect := board.get_global_control_rect(board.board_zone)
	_send_motion(source, false)
	await process_frame
	print("SOURCE point=", source, " hovered=", root.gui_get_hovered_control().get_path() if root.gui_get_hovered_control() != null else "<none>", " card=", card.get_path(), " available=", (card as HerbCard).available)
	_send_button(source, true)
	await process_frame
	for distance: float in [8.0, 20.0, 45.0]:
		_send_motion(source + Vector2(-distance, distance * 0.5), true)
		await process_frame
	if not root.gui_is_dragging():
		var preview := Label.new()
		preview.text = "probe"
		card.force_drag((card as HerbCard)._get_drag_data(Vector2.ZERO), preview)
		await process_frame
	print("DRAG started=", root.gui_is_dragging(), " data=", root.gui_get_drag_data())
	for ratio: float in [0.03, 0.5, 0.97]:
		var target := Vector2(board_rect.get_center().x, lerpf(board_rect.position.y, board_rect.end.y, ratio))
		_send_motion(target, true)
		await process_frame
		var hovered := root.gui_get_hovered_control()
		print("DRAG ratio=", ratio, " point=", target, " hovered=", hovered.get_path() if hovered != null else "<none>", " cursor=", DisplayServer.cursor_get_shape())
	_send_button(board_rect.get_center(), false)
	await process_frame
	print("DRAG ended=", root.gui_is_dragging(), " sources=", panel.source_herbs.size())
	quit(0)


func _send_motion(point: Vector2, left_down: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if left_down else 0
	Input.parse_input_event(event)


func _send_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
