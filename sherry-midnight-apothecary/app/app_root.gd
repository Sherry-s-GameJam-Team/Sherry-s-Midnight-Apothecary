class_name AppRoot
extends Node

const SettingsServiceScript := preload("res://app/settings_service.gd")

@export var start_automatically := false

@onready var game_flow: GameFlow = $GameFlow
@onready var settings_service: Node = $SettingsService
@onready var menu_controller: MenuController = $MenuSlot/Menu
@onready var current_runtime_slot: Node = $CurrentRuntime
@onready var global_ui: CanvasLayer = $GlobalUI
@onready var pause_menu: PauseMenu = $GlobalUI/PauseMenu
@onready var top_hint_ui: TopHintUI = $GlobalUI/TopHintUI
@onready var map_switch: Control = $GlobalUI/MapSwitchInteraction
@onready var sleep_fade: ColorRect = $SleepTransition/Fade

var player_data: PlayerData
var save_service: SaveService
var _sleep_transition_running := false


func get_player_data() -> PlayerData:
	return player_data


func _ready() -> void:
	settings_service.load_and_apply()
	save_service = SaveService.new()
	player_data = PlayerData.new()
	top_hint_ui.bind_player_data(player_data)
	pause_menu.bind_player_data(player_data)
	pause_menu.bind_settings(settings_service)
	menu_controller.bind_settings(settings_service)
	game_flow.configure(current_runtime_slot, player_data)
	map_switch.travel_requested.connect(_on_map_switch_travel_requested)
	game_flow.save_requested.connect(_on_save_requested)
	game_flow.sleep_transition_requested.connect(_on_sleep_transition_requested)
	menu_controller.runtime_swap_requested.connect(_on_menu_runtime_swap_requested)
	menu_controller.settings_requested.connect(_on_menu_settings_requested)
	menu_controller.intro_finished.connect(_on_menu_intro_finished)
	pause_menu.resumed.connect(_on_pause_menu_resumed)
	if start_automatically:
		start_new_game()
		menu_controller.queue_free()
		global_ui.visible = true
	else:
		global_ui.visible = false
		menu_controller.configure(save_service.load_game())


func start_new_game(
	initial_day_level_id: StringName = &"",
	defer_day_presentation := false,
	defer_day_title := false
) -> void:
	player_data.reset()
	top_hint_ui.bind_player_data(player_data)
	pause_menu.bind_player_data(player_data)
	game_flow.configure(current_runtime_slot, player_data)
	game_flow.start_new_game(initial_day_level_id, defer_day_presentation, defer_day_title)


func save_game() -> Error:
	return save_service.save_game(game_flow.current_day, game_flow.current_mode, player_data)


func load_game(
	initial_day_level_id: StringName = &"",
	defer_day_presentation := false,
	defer_day_title := false
) -> bool:
	var save_data := save_service.load_game()
	if save_data.is_empty():
		return false
	player_data = PlayerData.from_save_data(save_data.get("player", {}))
	top_hint_ui.bind_player_data(player_data)
	pause_menu.bind_player_data(player_data)
	game_flow.configure(current_runtime_slot, player_data)
	return game_flow.resume_game(
		int(save_data.get("day", 1)),
		int(save_data.get("mode", GameFlow.Mode.DAY)) as GameFlow.Mode,
		initial_day_level_id,
		defer_day_presentation,
		defer_day_title
	)


func _on_menu_runtime_swap_requested(continue_game: bool) -> void:
	var loaded := false
	if continue_game:
		var save_data := save_service.load_game()
		var saved_mode := int(save_data.get("mode", GameFlow.Mode.DAY))
		var is_day := saved_mode == GameFlow.Mode.DAY
		loaded = load_game(&"bedroom" if is_day else &"", is_day, is_day)
	else:
		start_new_game(&"bedroom", true, true)
		loaded = is_instance_valid(game_flow.current_runtime)
		if loaded:
			save_game()
	if not loaded and game_flow.current_mode != GameFlow.Mode.ENDING:
		menu_controller.fail_transition("Unable to create the requested game runtime.")
		return
	menu_controller.runtime_loaded(game_flow.current_runtime, game_flow.current_mode, game_flow.current_day)


func _on_menu_settings_requested() -> void:
	global_ui.visible = true
	pause_menu.open(PauseMenu.Page.SETTINGS)


func _on_pause_menu_resumed() -> void:
	if is_instance_valid(menu_controller) and menu_controller.state != MenuController.MenuState.FINISHED:
		global_ui.visible = false


func _on_menu_intro_finished() -> void:
	global_ui.visible = true
	if is_instance_valid(menu_controller):
		menu_controller.queue_free()


func _on_save_requested(_day: int, _mode: GameFlow.Mode) -> void:
	save_game()


func _on_sleep_transition_requested(result: NightResult) -> void:
	if _sleep_transition_running or game_flow.current_mode != GameFlow.Mode.NIGHT:
		return
	_sleep_transition_running = true
	sleep_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_out := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(sleep_fade, "color:a", 1.0, 0.8)
	await fade_out.finished
	var changed := game_flow.complete_night_to_bedroom(result)
	if changed and game_flow.current_mode == GameFlow.Mode.DAY:
		await get_tree().process_frame
		await get_tree().process_frame
		var fade_in := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade_in.tween_property(sleep_fade, "color:a", 0.0, 0.8)
		await fade_in.finished
	elif not changed:
		sleep_fade.color.a = 0.0
	if game_flow.current_mode != GameFlow.Mode.ENDING:
		sleep_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().remove_meta("day_modal_input_locked")
	_sleep_transition_running = false


func _on_map_switch_travel_requested(destination_id: StringName, _destination_data: Dictionary) -> void:
	if game_flow.current_mode != GameFlow.Mode.DAY or not (game_flow.current_runtime is DayRuntime):
		push_warning("MapSwitch travel is only available during the day: %s" % destination_id)
		return
	if map_switch.has_method("close"):
		map_switch.call("close")
	var day_runtime := game_flow.current_runtime as DayRuntime
	if not day_runtime.switch_to_level(str(destination_id), &"default"):
		push_warning("MapSwitch destination is not a registered day level: %s" % destination_id)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(menu_controller) and menu_controller.state != MenuController.MenuState.FINISHED:
		return
	if get_tree().has_meta("day_modal_input_locked"):
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if event.is_action_pressed("open_backpack") and not pause_menu.visible:
		pause_menu.open(PauseMenu.Page.BACKPACK)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not pause_menu.visible:
		pause_menu.open()
		get_viewport().set_input_as_handled()
