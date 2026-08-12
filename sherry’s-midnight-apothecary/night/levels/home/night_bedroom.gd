class_name NightBedroom
extends Node2D

signal return_requested

var _standalone_player_data: PlayerData


func get_player_data() -> PlayerData:
	var runtime := _find_night_runtime()
	if runtime != null:
		return runtime.get_player_data()
	if _standalone_player_data == null:
		_standalone_player_data = PlayerData.new()
	return _standalone_player_data


func request_return() -> void:
	return_requested.emit()


func _find_night_runtime() -> NightRuntime:
	var current := get_parent()
	while current != null:
		if current is NightRuntime:
			return current as NightRuntime
		current = current.get_parent()
	return null
