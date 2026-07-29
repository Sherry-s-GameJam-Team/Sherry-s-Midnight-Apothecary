class_name NightRuntime
extends Node

signal finished(result: NightResult)

var player_data: PlayerData
var day := 1


func configure(shared_player_data: PlayerData, current_day: int) -> void:
	player_data = shared_player_data
	day = current_day


func finish_night(result: NightResult) -> void:
	if result != null:
		finished.emit(result)

