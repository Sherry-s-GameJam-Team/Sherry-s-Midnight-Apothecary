class_name PotionSpectrumUnlockState
extends Resource

signal state_changed()

@export var unlocked_function_ids: Array[StringName] = []
@export var unlocked_recipe_ids: Array[StringName] = []
@export var unlocked_matrix_cells: Array[Vector2i] = []
var player_data: PlayerData


func configure_player_data(shared_player_data: PlayerData) -> void:
	player_data = shared_player_data
	if player_data == null:
		return
	unlocked_function_ids = player_data.codex_unlocked_function_ids.duplicate()
	unlocked_recipe_ids = player_data.codex_unlocked_recipe_ids.duplicate()
	unlocked_matrix_cells = player_data.codex_unlocked_matrix_cells.duplicate()
	state_changed.emit()


func is_function_unlocked(func_id: StringName) -> bool:
	return unlocked_function_ids.has(func_id)


func is_recipe_unlocked(recipe_id: StringName) -> bool:
	return unlocked_recipe_ids.has(recipe_id)


func is_matrix_cell_unlocked(cell: Vector2i) -> bool:
	return unlocked_matrix_cells.has(cell)


func unlock_function(func_id: StringName) -> bool:
	if func_id.is_empty():
		return false
	if not unlocked_function_ids.has(func_id):
		unlocked_function_ids.append(func_id)
		if player_data != null:
			player_data.unlock_codex_function(func_id)
		state_changed.emit()
		return true
	return false


func unlock_recipe(recipe_id: StringName) -> bool:
	if recipe_id.is_empty():
		return false
	if not unlocked_recipe_ids.has(recipe_id):
		unlocked_recipe_ids.append(recipe_id)
		if player_data != null:
			player_data.unlock_potion_recipe(recipe_id)
		state_changed.emit()
		return true
	return false


func unlock_matrix_cell(cell: Vector2i) -> bool:
	if not unlocked_matrix_cells.has(cell):
		unlocked_matrix_cells.append(cell)
		if player_data != null:
			player_data.unlock_codex_matrix_cell(cell)
		state_changed.emit()
		return true
	return false
