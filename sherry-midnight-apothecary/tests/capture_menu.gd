extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	print("Menu capture starting")
	var arguments := OS.get_cmdline_user_args()
	var width := int(arguments[0]) if arguments.size() > 0 else 1280
	var height := int(arguments[1]) if arguments.size() > 1 else 720
	var output_name := arguments[2] if arguments.size() > 2 else "menu_preview_1280x720.png"
	var preview_mode := arguments[3] if arguments.size() > 3 else "day"
	root.size = Vector2i(width, height)
	var menu_scene := load("res://menu/menu.tscn") as PackedScene
	if menu_scene == null:
		push_error("Menu scene could not be loaded for capture.")
		quit(1)
		return
	var menu := menu_scene.instantiate() as MenuController
	root.add_child(menu)
	var save_data := {"day": 1, "mode": GameFlow.Mode.NIGHT, "player": {}} if preview_mode == "night" else {}
	menu.configure(save_data)
	print("Menu capture scene ready")
	await process_frame
	print("Menu capture frame 1")
	await process_frame
	print("Menu capture frame 2")
	var image := root.get_viewport().get_texture().get_image()
	print("Menu capture image acquired")
	var output_path := "res://outputs/%s" % output_name
	var result := image.save_png(output_path)
	if result != OK:
		push_error("Failed to save menu capture: %s" % result)
		quit(1)
		return
	print("Menu capture: ", image.get_size(), " -> ", output_path)
	quit(0)
