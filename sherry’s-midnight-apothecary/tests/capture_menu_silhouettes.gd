extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var app := (load("res://app/app_root.tscn") as PackedScene).instantiate() as AppRoot
	app.start_automatically = false
	root.add_child(app)
	app.save_service = SaveService.new("res://tmp/menu_silhouette_capture_save.json")
	app.save_service.delete_save()
	(app.get_node("MenuSlot/Menu/MenuUILayer/MenuUI/MenuButtons/StartButton") as Button).pressed.emit()
	await create_timer(0.75).timeout
	_capture_frame("res://outputs/menu_silhouette_bird.png")
	await create_timer(1.85).timeout
	_capture_frame("res://outputs/menu_silhouette_tree.png")
	await create_timer(1.5).timeout
	_capture_frame("res://outputs/menu_silhouette_roof.png")
	app.save_service.delete_save()
	quit(0)


func _capture_frame(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(path)
