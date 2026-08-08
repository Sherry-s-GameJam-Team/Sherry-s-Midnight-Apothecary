class_name AppRoot
extends Node

@export var start_automatically := true

@onready var game_flow: GameFlow = $GameFlow
@onready var current_runtime_slot: Node = $CurrentRuntime
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
	if start_automatically:
		start_new_game()


func start_new_game() -> void:
	player_data.reset()
	top_hint_ui.bind_player_data(player_data)
	pause_menu.bind_player_data(player_data)
	game_flow.configure(current_runtime_slot, player_data)
	game_flow.start_new_game()


func save_game() -> Error:
	return save_service.save_game(game_flow.current_day, game_flow.current_mode, player_data)


func load_game() -> bool:
	var save_data := save_service.load_game()
	if save_data.is_empty():
		return false
	player_data = PlayerData.from_save_data(save_data.get("player", {}))
	top_hint_ui.bind_player_data(player_data)
	pause_menu.bind_player_data(player_data)
	game_flow.configure(current_runtime_slot, player_data)
	return game_flow.resume_game(
		int(save_data.get("day", 1)),
		int(save_data.get("mode", GameFlow.Mode.DAY)) as GameFlow.Mode
	)


func _on_save_requested(_day: int, _mode: GameFlow.Mode) -> void:
	save_game()


func _on_map_switch_travel_requested(destination_id: StringName, _destination_data: Dictionary) -> void:
	print("[MapSwitch] travel requested: ", destination_id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not pause_menu.visible:
		pause_menu.open()
		get_viewport().set_input_as_handled()
