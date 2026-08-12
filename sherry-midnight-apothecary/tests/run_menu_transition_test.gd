extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://app/app_root.tscn") as PackedScene
	if scene == null:
		_fail("AppRoot could not be loaded.")
		return
	var app := scene.instantiate() as AppRoot
	app.start_automatically = false
	root.add_child(app)
	app.save_service = SaveService.new("res://tmp/menu_transition_test_save.json")
	app.save_service.delete_save()
	var saved_player := PlayerData.new()
	saved_player.tutorial_flags["sleep_to_wake_day_1"] = true
	if app.save_service.save_game(1, GameFlow.Mode.DAY, saved_player) != OK:
		_fail("Could not create the isolated menu transition save.")
		return
	app.menu_controller.configure(app.save_service.load_game())
	Engine.time_scale = 12.0
	var continue_button := app.get_node("MenuSlot/Menu/MenuUILayer/MenuUI/MenuButtons/ContinueButton") as Button
	continue_button.pressed.emit()
	var completed := false
	var saw_wake_animation := false
	var saw_wake_during_reveal := false
	var saw_camera_processing_during_wake := false
	var saw_bedroom_camera_own_viewport := false
	var saw_intro_ui_locked := false
	var saw_indoor_title := false
	var saw_bird_flight := false
	var saw_bird_move_left := false
	var saw_bird_finish := false
	var bird_start_x := INF
	for _frame_index in range(900):
		await process_frame
		if is_instance_valid(app.menu_controller):
			var silhouette_director := app.menu_controller.silhouette_director
			var bird := app.menu_controller.get_node("World/SilhouetteLayers/BirdSilhouette") as Sprite2D
			bird_start_x = silhouette_director.get_bird_start_x()
			saw_bird_flight = saw_bird_flight or bird.visible or silhouette_director.is_running() or silhouette_director.has_completed()
			saw_bird_move_left = saw_bird_move_left or bird.global_position.x < bird_start_x
			saw_bird_finish = saw_bird_finish or silhouette_director.has_completed()
		var active_runtime := app.game_flow.current_runtime as DayRuntime
		if active_runtime != null and active_runtime.current_level_instance != null:
			var wake_animation := active_runtime.current_level_instance.get_node_or_null("SleepToWake") as AnimatedSprite2D
			if wake_animation != null and wake_animation.is_playing():
				saw_wake_animation = true
				var active_camera := active_runtime.current_level_instance.get_node("Player/Camera2D") as Camera2D
				saw_camera_processing_during_wake = saw_camera_processing_during_wake or active_camera.can_process()
				saw_bedroom_camera_own_viewport = saw_bedroom_camera_own_viewport or root.get_viewport().get_camera_2d() == active_camera
				saw_intro_ui_locked = saw_intro_ui_locked or not active_runtime.gameplay_ui.visible
				if is_instance_valid(app.menu_controller):
					saw_wake_during_reveal = saw_wake_during_reveal or app.menu_controller.transition_director.is_revealing()
			if active_runtime.scene_title_card.screen_root.visible:
				saw_indoor_title = true
		if not is_instance_valid(app.menu_controller):
			completed = true
			break
	if not completed:
		_fail("Menu cinematic did not complete within the integration timeout.")
		return
	var runtime := app.game_flow.current_runtime as DayRuntime
	if runtime == null or runtime.current_level == null or runtime.current_level.id != &"bedroom":
		_fail("Menu cinematic did not finish in the bedroom DayRuntime.")
		return
	var player := runtime.current_level_instance.get_node("Player") as CharacterBody2D
	if not player.visible or not player.is_physics_processing():
		_fail("Bedroom player control was not restored after wake-up.")
		return
	if not saw_wake_animation:
		_fail("The saved tutorial flag skipped the visible SleepToWake animation.")
		return
	if not saw_wake_during_reveal:
		_fail("SleepToWake did not overlap the roof reveal as the loading presentation.")
		return
	if not saw_camera_processing_during_wake:
		_fail("Bedroom camera stopped processing during SleepToWake.")
		return
	if not saw_bedroom_camera_own_viewport:
		_fail("The menu camera retained the viewport during SleepToWake.")
		return
	if not saw_intro_ui_locked or not runtime.gameplay_ui.visible:
		_fail("DayRuntime gameplay UI was not locked during wake-up and restored afterward.")
		return
	if saw_indoor_title:
		_fail("Bedroom displayed a level title card during the menu intro.")
		return
	if not saw_bird_flight:
		_fail("Menu bird silhouette never became visible.")
		return
	if not saw_bird_move_left:
		_fail("Menu bird silhouette did not move left from its start position.")
		return
	if not saw_bird_finish:
		_fail("Menu bird silhouette did not finish its single flight before the menu was released.")
		return
	app.save_service.delete_save()
	Engine.time_scale = 1.0
	print("Menu cinematic integration passed with saved wake flag: roof swap -> forced wake-up -> player restored.")
	app.free()
	quit(0)


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	push_error(message)
	quit(1)
