class_name AppRoot
extends Node

@export var start_automatically := false

@onready var game_flow: GameFlow = $GameFlow
@onready var menu_controller: MenuController = $MenuSlot/Menu
@onready var current_runtime_slot: Node = $CurrentRuntime
@onready var global_ui: CanvasLayer = $GlobalUI
@onready var pause_menu: PauseMenu = $GlobalUI/PauseMenu
@onready var top_hint_ui: TopHintUI = $GlobalUI/TopHintUI
@onready var map_switch: Control = $GlobalUI/MapSwitchInteraction

var player_data: PlayerData
var save_service: SaveService


func _ready() -> void:
	save_service = SaveService.new()
	player_data = PlayerData.new()
	top_hint_ui.bind_player_data(player_data)
	pause_menu.bind_player_data(player_data)
	game_flow.configure(current_runtime_slot, player_data)
	map_switch.travel_requested.connect(_on_map_switch_travel_requested)
	game_flow.save_requested.connect(_on_save_requested)
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


func _on_map_switch_travel_requested(destination_id: StringName, _destination_data: Dictionary) -> void:
	print("[MapSwitch] travel requested: ", destination_id)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(menu_controller) and menu_controller.state != MenuController.MenuState.FINISHED:
		return
	if event.is_action_pressed("ui_cancel") and not pause_menu.visible:
		pause_menu.open()
		get_viewport().set_input_as_handled()
