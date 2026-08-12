extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("POTION RUNTIME TEST FAILED: %s" % message)


func _run() -> void:
	for action_name in ["potion_aim", "potion_cancel", "potion_slot_1", "potion_slot_8", "potion_next_slot", "potion_previous_slot"]:
		_expect(InputMap.has_action(action_name) and not InputMap.action_get_events(action_name).is_empty(), "%s has a default InputMap binding." % action_name)
	var player := PlayerData.from_save_data({
		"equipped_potion_ids": ["red_potion", "green_potion", ""],
		"potions": {
			"red_potion": [{"instance_uid": "runtime-red", "remaining_dose": 1.0, "quality": 0.9}],
			"green_potion": [{"instance_uid": "runtime-green", "remaining_dose": 0.5, "quality": 1.1}],
			"black_potion": [{"instance_uid": "runtime-black", "remaining_dose": 1.0, "quality": 0.5}],
		}
	})
	_expect(not player.equip_potion(0, &"black_potion"), "Black potion cannot be equipped.")
	var runtime: DayRuntime = preload("res://day/day_runtime.tscn").instantiate()
	runtime.configure(player, 1)
	root.add_child(runtime)
	await process_frame
	await process_frame
	await process_frame
	var day_console: DeveloperConsole = runtime.developer_console
	day_console.open()
	_expect(not paused, "Opening the daytime console keeps gameplay running.")
	_expect(day_console.command_input.has_focus(), "Opening the daytime console captures keyboard input.")
	var focused_level := runtime.level_slot.get_child(runtime.level_slot.get_child_count() - 1)
	var focused_player := focused_level.get_node("Player")
	var focused_thrower: PotionThrower = focused_player.get_node("PotionThrower")
	var selected_before_typing: int = player.selected_potion_slot
	var number_event := InputEventKey.new()
	number_event.physical_keycode = KEY_2
	number_event.pressed = true
	focused_thrower._input(number_event)
	_expect(player.selected_potion_slot == selected_before_typing, "Number keys cannot change potion slots while console text input is focused.")
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	_expect(not focused_thrower._should_block_for_console(mouse_event), "Console keyboard focus does not block potion mouse input.")
	focused_thrower._unhandled_input(mouse_event)
	_expect(focused_thrower._aiming, "Left mouse press starts potion aiming while console keyboard focus is active.")
	if focused_thrower._aiming:
		focused_thrower.cancel_aim()
	var action_before_typing: String = focused_player._state
	var space_event := InputEventKey.new()
	space_event.keycode = KEY_SPACE
	space_event.pressed = true
	focused_player._unhandled_key_input(space_event)
	_expect(focused_player._state == action_before_typing, "Space cannot trigger the player while console text input is focused.")
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	day_console._input(escape_event)
	_expect(not day_console.visible and not day_console.command_input.has_focus(), "Escape closes the daytime console and returns keyboard control to gameplay.")
	_expect(focused_thrower._begin_aim(), "A stocked selected potion can begin aiming.")
	if focused_thrower._aiming:
		var cast_observation := {"projectile": null, "texture": null, "received_splash": false}
		focused_thrower.projectile_spawned.connect(func(projectile: PotionProjectile) -> void:
			cast_observation["projectile"] = projectile
			cast_observation["texture"] = projectile.bottle_sprite.texture
			projectile.broken.connect(func(_point: Vector2, _normal: Vector2) -> void: cast_observation["received_splash"] = true)
		)
		focused_thrower._aiming = false
		focused_thrower._casting = true
		focused_thrower._pending_velocity = Vector2(440.0, -260.0)
		focused_player.play_potion_cast()
		await create_timer(0.9, true, false, true).timeout
		var spawned_projectile := cast_observation["projectile"] as PotionProjectile
		_expect(spawned_projectile != null, "Cast release frame spawns a potion projectile.")
		_expect(cast_observation["texture"] != null, "Spawned potion projectile has a bottle texture.")
		if spawned_projectile != null and is_instance_valid(spawned_projectile):
			spawned_projectile._break(spawned_projectile.global_position, Vector2.UP)
			await process_frame
		_expect(bool(cast_observation["received_splash"]), "Broken potion projectile creates splash feedback.")
	var standalone_level := DayLevelEnvironment.new()
	var standalone_console: DeveloperConsole = preload("res://night/ui/developer_console/developer_console.tscn").instantiate()
	root.add_child(standalone_level)
	standalone_level.add_child(standalone_console)
	standalone_console.setup_day_scene(standalone_level)
	_expect(standalone_console.execute_command("potion 1 1") == "potions.red_potion = 1", "Standalone day scenes create PlayerData and accept numeric potion IDs.")
	_expect(standalone_level.get_player_data().potions.has(&"red_potion"), "Standalone console and level share the same PlayerData.")
	standalone_level.queue_free()
	await process_frame
	for scene_path in [
		"res://day/levels/market/town/town.tscn",
		"res://day/levels/home/home.tscn",
		"res://day/art/raintree/raintree.tscn",
		"res://day/art/lake/lake.tscn",
	]:
		var standalone_scene: DayLevelEnvironment = load(scene_path).instantiate()
		root.add_child(standalone_scene)
		await process_frame
		await process_frame
		var embedded_console: DeveloperConsole = standalone_scene.get_node("DebugUI/DeveloperConsole")
		_expect(embedded_console.day_scene == standalone_scene, "%s embedded console is connected to its standalone scene." % scene_path)
		embedded_console.day_scene = null
		embedded_console.day_runtime = null
		_expect(embedded_console.execute_command("potion 1 1") == "potions.red_potion = 1", "%s embedded console can add a potion." % scene_path)
		var standalone_thrower: PotionThrower = standalone_scene.get_node("Player/PotionThrower")
		_expect(standalone_thrower.inventory_service != null, "%s standalone thrower receives PlayerData." % scene_path)
		if standalone_thrower.inventory_service != null:
			_expect(standalone_thrower.inventory_service.player_data == standalone_scene.get_player_data(), "%s console and thrower share PlayerData." % scene_path)
		standalone_scene.queue_free()
		await process_frame
	await _verify_loaded_level(runtime, "Town")
	_expect(runtime.switch_to_level("forest"), "RainTree level can be selected.")
	await process_frame
	await process_frame
	await _verify_loaded_level(runtime, "RainTree")
	_expect(runtime.switch_to_level("lake"), "Lake level can be selected.")
	await process_frame
	await process_frame
	await _verify_loaded_level(runtime, "Lake")
	var animation_library: AnimationLibrary = load("res://characters/sherry/sherry_animations.tres")
	for animation_name in [&"cast", &"cast_right"]:
		var animation := animation_library.get_animation(animation_name)
		var has_release_method := false
		for track_index in range(animation.get_track_count()):
			if animation.track_get_type(track_index) == Animation.TYPE_METHOD and animation.method_track_get_name(track_index, 0) == &"potion_cast_release":
				has_release_method = animation.track_get_path(track_index) == NodePath("..")
		_expect(has_release_method, "%s has an explicit release method frame." % animation_name)
	runtime.queue_free()
	await process_frame
	await process_frame
	PotionSvgRenderer.clear_cache()
	Engine.time_scale = 1.0
	if failures == 0:
		print("Potion runtime integration tests passed for Town, RainTree and Lake.")
		call_deferred("quit", 0)
	else:
		push_error("%d potion runtime assertion(s) failed." % failures)
		call_deferred("quit", 1)


func _verify_loaded_level(runtime: DayRuntime, expected_name: String) -> void:
	var level := runtime.level_slot.get_child(runtime.level_slot.get_child_count() - 1)
	_expect(level.name == expected_name, "%s scene is the active day level." % expected_name)
	var player := level.get_node_or_null("Player")
	_expect(player is CharacterBody2D, "%s uses CharacterBody2D player." % expected_name)
	var thrower: PotionThrower = player.get_node_or_null("PotionThrower")
	_expect(thrower != null, "%s includes shared PotionThrower." % expected_name)
	if thrower != null:
		await process_frame
		_expect(thrower.inventory_service != null, "%s PotionThrower receives shared PlayerData." % expected_name)
		_expect(thrower.hotbar._slot_buttons.size() == 3, "%s starts with three potion slots." % expected_name)
		if not thrower.hotbar._slot_buttons.is_empty():
			_expect(thrower.hotbar._slot_buttons[0].icon != null, "%s hotbar renders its SVG bottle icon." % expected_name)
		if expected_name == "Town":
			var slot_event := InputEventAction.new()
			slot_event.action = &"potion_slot_2"
			slot_event.pressed = true
			thrower._handle_slot_input(slot_event)
			_expect(thrower.inventory_service.player_data.selected_potion_slot == 1, "Numeric action selects the second potion slot.")
			var next_event := InputEventAction.new()
			next_event.action = &"potion_next_slot"
			next_event.pressed = true
			thrower._handle_slot_input(next_event)
			_expect(thrower.inventory_service.player_data.selected_potion_slot == 2, "Mouse-wheel action cycles unlocked slots.")
			thrower.hotbar._on_slot_pressed(0)
			_expect(thrower.inventory_service.player_data.selected_potion_slot == 0, "Hotbar click selects a potion slot.")
