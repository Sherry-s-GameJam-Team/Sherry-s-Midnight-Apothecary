extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("PLAYER MOVEMENT REGRESSION FAILED: %s" % message)


func _run() -> void:
	var runtime: DayRuntime = preload("res://day/day_runtime.tscn").instantiate()
	runtime.configure(PlayerData.new(), 1)
	root.add_child(runtime)
	for _frame in range(90):
		await physics_frame
	var level := runtime.level_slot.get_child(runtime.level_slot.get_child_count() - 1)
	var player := level.get_node("Player")
	_expect(player.is_on_floor(), "Shared player settles on the Town floor.")
	var start_x: float = player.global_position.x
	Input.action_press("ui_right")
	for _frame in range(24):
		await physics_frame
	Input.action_release("ui_right")
	_expect(player.global_position.x > start_x + 10.0, "Original horizontal walking still moves CharacterBody2D.")
	_expect(player.run_speed > player.walk_speed, "The shared controller retains a distinct Shift running profile.")
	player._request_jump()
	await physics_frame
	_expect(player._is_airborne and player.velocity.y < 0.0, "Buffered W-style jump still launches the player.")
	for _frame in range(180):
		await physics_frame
		if player.is_on_floor() and not player._is_airborne:
			break
	_expect(player.is_on_floor() and not player._is_airborne, "Jump still returns through the landing state.")
	player._try_start_roll(KEY_D)
	player._try_start_roll(KEY_D)
	_expect(player._is_rolling, "Double-tap roll can still start on the ground.")
	var roll_start_x: float = player.global_position.x
	for _frame in range(30):
		await physics_frame
	_expect(player.global_position.x > roll_start_x, "Roll retains its horizontal movement.")
	runtime.queue_free()
	await process_frame
	await process_frame
	PotionSvgRenderer.clear_cache()
	if failures == 0:
		print("Shared movement, run, jump, landing and roll regression tests passed.")
		quit(0)
	else:
		push_error("%d player movement assertion(s) failed." % failures)
		quit(1)
