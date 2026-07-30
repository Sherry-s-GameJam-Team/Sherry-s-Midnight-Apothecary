class_name NightRuntime
extends Node

signal finished(result: NightResult)

var player_data: PlayerData
var day := 1
var current_night_result := NightResult.new()

@onready var alchemy_runtime: AlchemyRuntime = $AlchemySlot/AlchemyRuntime


func configure(shared_player_data: PlayerData, current_day: int) -> void:
	player_data = shared_player_data
	day = current_day
	current_night_result = NightResult.new()
	var alchemy := get_node_or_null("AlchemySlot/AlchemyRuntime") as AlchemyRuntime
	if alchemy == null:
		push_error("NightRuntime is missing its AlchemyRuntime scene.")
		return
	alchemy_runtime = alchemy
	alchemy_runtime.setup(player_data, current_night_result, day)


func finish_night(result: NightResult = null) -> void:
	var final_result := result if result != null else current_night_result
	if final_result != null:
		finished.emit(final_result)


func _on_alchemy_request_close() -> void:
	finish_night()
