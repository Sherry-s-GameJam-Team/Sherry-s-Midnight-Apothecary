extends SceneTree

## Smoke test for the golden_cliff day level deployment:
##  1. Standalone DebugUI console embedded in golden_cliff.tscn (global DeveloperConsole).
##  2. golden_cliff registered in DayRuntime.LEVELS so DayRuntime presents the
##     global SceneTitleCard (title UI must NOT be embedded in the level scene).
##  3. Global PauseMenu embedded in golden_cliff.tscn: B (open_backpack) opens the
##     backpack page, ESC (ui_cancel) opens/closes the menu (works standalone).
##
## Deliberately avoids static references to DayRuntime/DayLevelEnvironment/PauseMenu
## so day_runtime.gd only compiles at runtime in the game's real load order.
## Simulated key events set BOTH keycode and physical_keycode so they match the
## input map's action entries (Godot 4.6 event-based is_action_pressed).
## Run: godot --headless --path . --script res://tests/golden_cliff_smoke_test.gd

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Compile day_runtime.gd (preloads every LEVELS .tres, incl. golden_cliff)
	# before the level scene, exactly like the game startup path.
	_assert(load("res://day/day_runtime.tscn") != null, "day_runtime.tscn loads")
	var packed_scene := load("res://day/levels/golden_cliff/golden_cliff.tscn") as PackedScene
	_assert(packed_scene != null, "golden_cliff.tscn loads")
	if _failed:
		return

	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	# --- Console deployment -------------------------------------------------
	var debug_ui := scene.get_node_or_null("DebugUI") as CanvasLayer
	_assert(debug_ui != null, "DebugUI canvas layer is embedded")
	_assert(debug_ui == null or debug_ui.layer == 200, "DebugUI sits above gameplay on layer 200")
	var console := scene.get_node_or_null("DebugUI/DeveloperConsole")
	_assert(console != null, "DeveloperConsole is instanced under DebugUI")
	_assert(console == null or console.get_script() != null, "console script resolves")
	if _failed:
		return

	# --- TitleUI deployment -------------------------------------------------
	# SceneTitleCard is DayRuntime-owned; a level only needs to be in LEVELS.
	var levels: Array = (load("res://day/day_runtime.gd") as GDScript).get_script_constant_map().get("LEVELS", [])
	var found := false
	for level in levels:
		if level.id == &"golden_cliff":
			found = true
			_assert(level.content_scene == packed_scene, "level data content_scene is golden_cliff.tscn")
			_assert(level.show_title_card, "global SceneTitleCard is enabled for this level")
			_assert(level.disaster_name.length() > 0, "title card disaster name is set")
			_assert(level.normal_description.length() > 0, "title card normal description is set")
	_assert(found, "golden_cliff registered in DayRuntime.LEVELS")
	if _failed:
		return

	# --- EntrancePortal & Map Switch Anchor 3 deployment --------------------
	var from_home := scene.get_node_or_null("EntryPoints/from_home") as Marker2D
	_assert(from_home != null, "EntryPoints/from_home is deployed for Map Switch arrivals")
	var entrance_portal := scene.get_node_or_null("Gameplay/EntrancePortal") as Area2D
	_assert(entrance_portal != null, "Gameplay/EntrancePortal is instanced in golden_cliff.tscn")
	_assert(entrance_portal == null or entrance_portal.get("destination_level") == &"home", "EntrancePortal destination_level is home")
	_assert(entrance_portal == null or entrance_portal.get("destination_entry_id") == &"from_cliff", "EntrancePortal destination_entry_id is from_cliff")
	var map_scene := load("res://day/interactables/map_switch/data/map.tscn") as PackedScene
	_assert(map_scene != null, "map.tscn loads")
	if map_scene != null:
		var map_inst := map_scene.instantiate()
		var anchor3 := map_inst.get_node_or_null("AnchorPoints/Anchor03") as MapSwitchAnchor
		_assert(anchor3 != null, "AnchorPoints/Anchor03 exists in map.tscn")
		_assert(anchor3 == null or anchor3.destination_id == &"golden_cliff", "Anchor03 destination_id links to golden_cliff")
		map_inst.free()
	if _failed:
		return

	# --- Pause menu / B-key backpack deployment -----------------------------
	var pause_layer := scene.get_node_or_null("PauseMenuLayer") as CanvasLayer
	_assert(pause_layer != null, "PauseMenuLayer canvas layer is embedded")
	_assert(pause_layer == null or pause_layer.layer == 200, "PauseMenuLayer sits on layer 200")
	var pause_menu := scene.get_node_or_null("PauseMenuLayer/PauseMenu")
	_assert(pause_menu != null, "PauseMenu is instanced under PauseMenuLayer")
	_assert(pause_menu == null or pause_menu.get_script() != null, "pause menu script resolves")
	_assert(pause_menu == null or not pause_menu.visible, "pause menu starts hidden")
	if _failed:
		return

	# B key opens the pause menu on the backpack page; ESC closes it again.
	Input.parse_input_event(_key_event(KEY_B, true))
	await create_timer(0.05).timeout
	Input.parse_input_event(_key_event(KEY_B, false))
	await create_timer(0.05).timeout
	_assert(pause_menu.visible, "B key opens the pause menu")
	var page_enum: Dictionary = (pause_menu.script as GDScript).get_script_constant_map().get("Page", {})
	var backpack_page: int = page_enum.get("BACKPACK", -1)
	_assert(pause_menu.active_page == backpack_page, "B key selects the backpack page")
	if _failed:
		return
	Input.parse_input_event(_key_event(KEY_ESCAPE, true))
	await create_timer(0.05).timeout
	Input.parse_input_event(_key_event(KEY_ESCAPE, false))
	await create_timer(0.05).timeout
	_assert(not pause_menu.visible, "ESC closes the pause menu")
	_assert(not paused, "tree unpauses after closing the menu")
	if _failed:
		return

	print("GOLDEN_CLIFF_DEPLOY_TEST_OK")
	quit(0)

func _key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Golden cliff deploy test failed: %s" % message)
	quit(1)
