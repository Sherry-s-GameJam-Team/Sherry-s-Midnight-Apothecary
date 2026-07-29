class_name SaveService
extends RefCounted

const DEFAULT_SAVE_PATH := "user://save.json"

var save_path: String


func _init(path := DEFAULT_SAVE_PATH) -> void:
	save_path = path


func save_game(day: int, mode: GameFlow.Mode, player_data: PlayerData) -> Error:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var payload := {
		"day": day,
		"mode": int(mode),
		"player": player_data.to_save_data(),
	}
	file.store_string(JSON.stringify(payload, "\t"))
	return OK


func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func delete_save() -> Error:
	if not has_save():
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

