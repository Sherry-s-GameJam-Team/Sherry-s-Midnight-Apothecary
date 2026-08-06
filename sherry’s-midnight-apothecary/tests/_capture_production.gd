extends SceneTree

const ALCHEMY_SCENE := preload("res://night/alchemy/alchemy_runtime.tscn")
const HERB_ID := &"herdsmans_loaf_bush"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := ALCHEMY_SCENE.instantiate() as AlchemyRuntime
	root.add_child(runtime)
	var player := PlayerData.new()
	player.inventory = {HERB_ID: 1}
	runtime.setup(player, NightResult.new(), 1)
	runtime.current_panel = AlchemyRuntime.PanelMode.PRODUCTION
	runtime.horizontal_stage.position.x = -runtime.production_panel.position.x
	runtime.production_panel._on_herb_dropped(HERB_ID)
	runtime.production_panel.separate_herb()
	await process_frame
	await process_frame
	var board := runtime.production_panel.process_board
	var drop_surface := runtime.production_panel.get_node("HerbDropSurface") as Control
	print("workspace=", board.get_global_control_rect(board.get_node("Sprite2D/WorkspaceArt")))
	print("zones=", board.get_global_control_rect(board.zones))
	print("board_zone=", board.get_global_control_rect(board.board_zone))
	print("movement=", board.get_movement_rect())
	print("piece_layer=", board.get_global_control_rect(board.piece_drag_layer))
	print("drop_surface=", board.get_global_control_rect(drop_surface), " filter=", drop_surface.mouse_filter, " z=", drop_surface.z_index)
	var output_path := OS.get_environment("TEMP").path_join("codex_production_capture.png")
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	print("capture=", output_path, " error=", error, " size=", image.get_size())
	quit(0 if error == OK else 1)
