class_name DayRuntime
extends Node

signal finished(result: DayResult)

var player_data: PlayerData
var day := 1


func configure(shared_player_data: PlayerData, current_day: int) -> void:
	player_data = shared_player_data
	day = current_day


func finish_day(result: DayResult) -> void:
	if result != null:
		finished.emit(result)

