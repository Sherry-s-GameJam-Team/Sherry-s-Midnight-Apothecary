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
	test.expect_equal(console.execute_command("boss 2"), "已进入【血叶猎王·阿尔凯昂】Boss 挑战，并装备无限药水！", "Console accepts 'boss 2' command.")
	test.expect(player.potions.has(&"purification_potion") and player.potions[&"purification_potion"].size() >= 90, "'boss 2' equips bulk battle potions.")
	test.expect(player.potions.has(&"red_potion") and player.potions[&"red_potion"].size() >= 90, "'boss 2' equips red attack potions.")
	test.expect(player.potions.has(&"cyan_potion") and player.potions[&"cyan_potion"].size() >= 90, "'boss 2' equips cyan shield/wind potions.")
	test.expect_equal(console.execute_command("boos 2"), "已进入【血叶猎王·阿尔凯昂】Boss 挑战，并装备无限药水！", "Console accepts 'boos 2' alias command.")
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
	test.expect_equal(day_console.execute_command("scene town"), "scene = 流明街", "Console opens Town during the day.")
	test.expect_equal(day_console.execute_command("scene raintree"), "scene = 常霁云林", "Console opens RainTree during the day.")
	test.expect_equal(day_console.execute_command("scene lake"), "scene = Lake", "Console opens Lake during the day.")
	test.expect_equal(day_console.execute_command("title"), "标题动画已播放：Lake", "Console replays the current scene title.")
	test.expect_equal(day_console.execute_command("scene grassland"), "scene = 翡翠原", "Console opens Grassland during the day.")
	test.expect_equal(day_console.execute_command("scene grass"), "scene = 翡翠原", "Console accepts the short Grassland alias.")
	test.expect(day_console.execute_command("scene list").contains("[1] market"), "Console lists scene 1 market.")
	test.expect(day_console.execute_command("scene list").contains("[17] aurem_clockyard"), "Console lists scene 17 aurem_clockyard.")
	test.expect(day_console.execute_command("scene list").contains("[18] aurem_clockyard_inside"), "Console lists sub-scene 18 aurem_clockyard_inside.")
	test.expect(day_console.execute_command("scene list").contains("[24] control_system_demo"), "Console lists sub-scene 24 control_system_demo.")
	test.expect_equal(day_console.execute_command("scene 1"), "scene = 流明街", "Console opens scene 1 (Town/Market) by number.")
	test.expect_equal(day_console.execute_command("scene 17"), "scene = 奥勒姆钟庭", "Console opens scene 17 (Aurem Clockyard) by number.")
	test.expect_equal(day_console.execute_command("scene 18"), "scene = 奥勒姆巨钟塔·内部", "Console opens sub-scene 18 (Clockyard Inside) by number.")
	test.expect_equal(day_console.execute_command("scene 钟塔内部"), "scene = 奥勒姆巨钟塔·内部", "Console opens Clockyard Inside by chinese alias.")
	test.expect_equal(day_console.execute_command("scene 水下暗道"), "scene = 镜湖·水下暗道", "Console opens Lake Cliff Underwater by chinese alias.")
	test.expect_equal(day_console.execute_command("scene clockyard"), "scene = 奥勒姆钟庭", "Console opens Aurem Clockyard by english alias.")
	test.expect_equal(day_console.execute_command("scene 钟庭"), "scene = 奥勒姆钟庭", "Console opens Aurem Clockyard by chinese alias.")
	test.expect_equal(day_console.execute_command("scene 卧室"), "scene = Bedroom", "Console opens Bedroom by chinese name.")
	test.expect_equal(day_console.execute_command("scene vespervale"), "scene = 暮息庭院", "Console opens Vespervale Garden by english alias.")
	test.expect_equal(day_console.execute_command("scene 暮息庭院"), "scene = 暮息庭院", "Console opens Vespervale Garden by chinese name.")
	test.expect_equal(day_console.execute_command("scene garden"), "scene = 暮息庭院", "Console opens Vespervale Garden by garden alias.")
	test.expect(day_console.execute_command("scene 99").begins_with("错误：场景序号超出范围"), "Console rejects out of range scene number.")
	test.expect(day_console.execute_command("status").contains("mode=DAY"), "Day status reports the active scene.")
	day_runtime.free()
