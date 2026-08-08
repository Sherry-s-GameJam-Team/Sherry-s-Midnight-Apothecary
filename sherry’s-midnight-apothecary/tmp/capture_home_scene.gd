extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var home := load("res://day/levels/home/home.tscn") as PackedScene
	if home == null:
		push_error("Home scene could not be loaded.")
		quit(1)
		return
	root.add_child(home.instantiate())
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var output_path := "user://home_scene_capture.png"
	print("Home capture size: ", image.get_size(), " -> ", ProjectSettings.globalize_path(output_path))
	var result := image.save_png(output_path)
	if result != OK:
		push_error("Failed to save home scene capture: %s" % result)
		quit(1)
		return
	quit()
