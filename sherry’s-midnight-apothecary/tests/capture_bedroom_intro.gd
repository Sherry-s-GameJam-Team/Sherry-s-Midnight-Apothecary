extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var app := (load("res://app/app_root.tscn") as PackedScene).instantiate() as AppRoot
	app.start_automatically = false
	root.add_child(app)
	app.save_service = SaveService.new("res://tmp/bedroom_capture_save.json")
	app.save_service.delete_save()
	var saved_player := PlayerData.new()
	saved_player.tutorial_flags["sleep_to_wake_day_1"] = true
	app.save_service.save_game(1, GameFlow.Mode.DAY, saved_player)
	app.menu_controller.configure(app.save_service.load_game())
	Engine.time_scale = 6.0
	(app.get_node("MenuSlot/Menu/MenuUILayer/MenuUI/MenuButtons/ContinueButton") as Button).pressed.emit()
	for _frame_index in range(1200):
		await process_frame
		var runtime := app.game_flow.current_runtime as DayRuntime
		if runtime == null or runtime.current_level_instance == null or not is_instance_valid(app.menu_controller):
			continue
		var wake := runtime.current_level_instance.get_node_or_null("SleepToWake") as AnimatedSprite2D
		if wake == null or not wake.is_playing() or app.menu_controller.transition_director.is_revealing():
			continue
		if runtime.scene_title_card.screen_root.visible:
			push_error("Bedroom title card unexpectedly visible during capture.")
			quit(1)
			return
		if runtime.gameplay_ui.visible:
			push_error("Bedroom gameplay UI unexpectedly visible during loading capture.")
			quit(1)
			return
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var result := image.save_png("res://outputs/bedroom_intro_verify.png")
		app.save_service.delete_save()
		Engine.time_scale = 1.0
		print("Bedroom intro capture saved without title card; camera active: ", (runtime.current_level_instance.get_node("Player/Camera2D") as Camera2D).can_process())
		quit(0 if result == OK else 1)
		return
	Engine.time_scale = 1.0
	push_error("Bedroom intro capture timed out.")
	quit(1)
