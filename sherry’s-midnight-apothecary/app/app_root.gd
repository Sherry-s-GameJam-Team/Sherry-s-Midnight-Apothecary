class_name AppRoot
extends Node

@export var start_automatically := true

@onready var game_flow: GameFlow = $GameFlow
@onready var current_runtime_slot: Node = $CurrentRuntime

var player_data: PlayerData
var save_service: SaveService


func _ready() -> void:
	save_service = SaveService.new()
	player_data = PlayerData.new()
	game_flow.configure(current_runtime_slot, player_data)
	game_flow.save_requested.connect(_on_save_requested)
	if start_automatically:
		start_new_game()


func start_new_game() -> void:
	player_data.reset()
	game_flow.configure(current_runtime_slot, player_data)
	game_flow.start_new_game()


func save_game() -> Error:
	return save_service.save_game(game_flow.current_day, game_flow.current_mode, player_data)


func load_game() -> bool:
	var save_data := save_service.load_game()
	if save_data.is_empty():
		return false
	player_data = PlayerData.from_save_data(save_data.get("player", {}))
	game_flow.configure(current_runtime_slot, player_data)
	return game_flow.resume_game(
		int(save_data.get("day", 1)),
		int(save_data.get("mode", GameFlow.Mode.DAY)) as GameFlow.Mode
	)


func _on_save_requested(_day: int, _mode: GameFlow.Mode) -> void:
	save_game()
