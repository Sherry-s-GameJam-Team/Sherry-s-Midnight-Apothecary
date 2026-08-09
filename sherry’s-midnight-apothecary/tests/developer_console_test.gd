extends RefCounted

const NIGHT_SCENE := preload("res://night/night_runtime.tscn")
const DAY_SCENE := preload("res://day/day_runtime.tscn")


static func run(test: TestSupport) -> void:
	var runtime := NIGHT_SCENE.instantiate() as NightRuntime
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(runtime)
	var console := runtime.developer_console

	test.expect(console != null, "NightRuntime owns the developer console.")
	test.expect_equal(console.execute_command("set money 250"), "money = 250", "Console sets money.")
	var player := runtime.player_data
	test.expect(player != null, "Standalone NightRuntime console creates test PlayerData on first data command.")
	test.expect_equal(player.money, 250, "Money command mutates shared PlayerData.")
	test.expect_equal(console.execute_command("add health -25"), "health = 75", "Console adds a signed health delta.")
	test.expect_equal(console.execute_command("give herdsmans_loaf_bush 4"), "inventory.herdsmans_loaf_bush = 4", "Console gives ingredients.")
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 4, "Given ingredients enter shared inventory.")
	test.expect_equal(console.execute_command("give 1 5"), "inventory.herdsmans_loaf_bush = 9", "Console resolves a one-based plant number when giving ingredients.")
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 9, "Giving five of plant one updates the first formal herb instead of a numeric inventory ID.")
	test.expect(not player.inventory.has(&"1"), "Numeric plant selection never creates a numeric inventory key.")
	test.expect_equal(console.execute_command("give 2 3"), "inventory.stardust_puffy_lion = 3", "Console plant numbers follow the runtime ingredient order.")
	test.expect_equal(console.execute_command("take 2 1"), "inventory.stardust_puffy_lion = 2", "Taking ingredients supports the same numbered plant selection.")
	test.expect(console.execute_command("give 0 5").begins_with("错误：植物序号必须在"), "Plant number zero is rejected with the valid range.")
	test.expect(console.execute_command("give 999 5").begins_with("错误：植物序号必须在"), "Out-of-range plant numbers are rejected instead of creating inventory keys.")
	test.expect_equal(console.execute_command("give 6 2"), "inventory.praise_star_maple = 2", "Numbered give commands automatically include the newly registered tree ingredient.")
	console.execute_command("potion green_potion 2 1.25")
	test.expect_equal(player.potions[&"green_potion"].size(), 2, "Console creates dynamic potion instances.")
	test.expect_float_close(player.potions[&"green_potion"][0]["quality"], 1.25, 0.001, "Console potion quality is retained.")
	test.expect_equal(console.execute_command("temp 72"), "temp = 72.0", "Console changes current alchemy temperature.")
	test.expect_float_close(runtime.alchemy_runtime.temperature, 72.0, 0.001, "Temperature command reaches AlchemyRuntime.")
	test.expect(console.execute_command("status").contains("mode=NIGHT"), "Status reports current mode.")
	test.expect_equal(console.execute_command("get day"), "day = 1", "Console reads the NightRuntime day.")
	var toggle_event := InputEventKey.new()
	toggle_event.pressed = true
	toggle_event.physical_keycode = KEY_QUOTELEFT
	console._input(toggle_event)
	test.expect(console.visible and scene_tree.paused, "The console key opens the hidden console and pauses gameplay.")
	console._input(toggle_event)
	test.expect(not console.visible and not scene_tree.paused, "The console key closes it and restores pause state.")
	var fallback_event := InputEventKey.new()
	fallback_event.pressed = true
	fallback_event.keycode = KEY_F1
	console._input(fallback_event)
	test.expect(console.visible and scene_tree.paused, "F1 provides a layout-independent console fallback.")
	console._input(fallback_event)
	test.expect(not console.visible and not scene_tree.paused, "F1 also closes the console.")
	scene_tree.paused = true
	console._input(toggle_event)
	test.expect(console.visible and scene_tree.paused, "The always-processing console can open while gameplay is already paused.")
	console._input(toggle_event)
	test.expect(not console.visible and scene_tree.paused, "Closing restores the pause state that existed before opening.")
	scene_tree.paused = false

	runtime.free()

	var day_runtime := DAY_SCENE.instantiate() as DayRuntime
	scene_tree.root.add_child(day_runtime)
	var day_console := day_runtime.developer_console
	test.expect(day_console != null, "DayRuntime owns the developer console.")
	test.expect(day_runtime.developer_console_layer.layer > 210, "Day console renders above the shared alchemy CanvasLayer.")
	day_console._input(fallback_event)
	test.expect(day_console.visible and not scene_tree.paused and day_console.command_input.has_focus(), "F1 opens a usable live daytime console without pausing DayRuntime.")
	day_console._input(fallback_event)
	test.expect(not day_console.visible and not scene_tree.paused, "F1 closes the daytime console cleanly.")
	test.expect_equal(day_console.execute_command("scene town"), "scene = Town", "Console opens Town during the day.")
	test.expect_equal(day_console.execute_command("scene raintree"), "scene = Rain Tree", "Console opens RainTree during the day.")
	test.expect_equal(day_console.execute_command("scene lake"), "scene = Lake", "Console opens Lake during the day.")
	test.expect_equal(day_console.execute_command("title"), "标题动画已播放：Lake", "Console replays the current scene title.")
	test.expect(day_console.execute_command("status").contains("mode=DAY"), "Day status reports the active scene.")
	day_runtime.free()
