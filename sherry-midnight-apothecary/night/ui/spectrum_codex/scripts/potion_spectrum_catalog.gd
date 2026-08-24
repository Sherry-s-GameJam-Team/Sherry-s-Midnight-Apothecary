class_name PotionSpectrumCatalog
extends Resource

@export var bands: Array[PotionSpectrumBand] = []
@export var functions: Array[PotionFunctionDefinition] = []
@export var recipes: Array[PotionRecipeDefinition] = []
@export var effect_matrix: PotionEffectMatrix
@export var matrix_row_labels: Array[String] = []
@export var matrix_col_labels: Array[String] = []


func get_band(band_id: StringName) -> PotionSpectrumBand:
	for b in bands:
		if b != null and b.id == band_id:
			return b
	return null


func get_function(func_id: StringName) -> PotionFunctionDefinition:
	for f in functions:
		if f != null and f.id == func_id:
			return f
	return null


func get_recipe(recipe_id: StringName) -> PotionRecipeDefinition:
	for r in recipes:
		if r != null and r.id == recipe_id:
			return r
	return null


func get_brew_unlock_recipe(potion_id: StringName) -> PotionRecipeDefinition:
	for recipe in recipes:
		if recipe != null and recipe.unlock_on_brew and recipe.produced_potion_id == potion_id:
			return recipe
	return null


func get_effect_combination(primary_effect_id: StringName, secondary_effect_id: StringName = &"") -> PotionEffectCombination:
	return effect_matrix.get_combination(primary_effect_id, secondary_effect_id) if effect_matrix != null else null


func get_effect_combination_at(row: int, col: int) -> PotionEffectCombination:
	return effect_matrix.get_combination_at(row, col) if effect_matrix != null else null


func effect_matrix_coordinate(primary_effect_id: StringName, secondary_effect_id: StringName = &"") -> Vector2i:
	return effect_matrix.coordinate_for(primary_effect_id, secondary_effect_id) if effect_matrix != null else Vector2i(-1, -1)


func get_functions_for_band(band_id: StringName) -> Array[PotionFunctionDefinition]:
	var result: Array[PotionFunctionDefinition] = []
	for f in functions:
		if f != null and f.band_id == band_id:
			result.append(f)
	result.sort_custom(func(a: PotionFunctionDefinition, b: PotionFunctionDefinition) -> bool:
		return a.sort_index < b.sort_index
	)
	return result


func get_recipes_for_function(func_id: StringName) -> Array[PotionRecipeDefinition]:
	var result: Array[PotionRecipeDefinition] = []
	for r in recipes:
		if r != null and r.function_id == func_id:
			result.append(r)
	return result


func get_recipes_for_matrix_cell(row: int, col: int) -> Array[PotionRecipeDefinition]:
	var result: Array[PotionRecipeDefinition] = []
	for r in recipes:
		if r != null and r.matrix_row == row and r.matrix_col == col:
			result.append(r)
	return result


func get_bands_sorted() -> Array[PotionSpectrumBand]:
	var result: Array[PotionSpectrumBand] = []
	for b in bands:
		if b != null:
			result.append(b)
	result.sort_custom(func(a: PotionSpectrumBand, b: PotionSpectrumBand) -> bool:
		if is_equal_approx(a.spectrum_min, b.spectrum_min):
			return a.order < b.order
		return a.spectrum_min < b.spectrum_min
	)
	return result
