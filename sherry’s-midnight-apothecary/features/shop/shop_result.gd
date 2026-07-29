class_name ShopResult
extends RefCounted

var earned_money := 0
var spent_ingredients: Dictionary = {}
var produced_potions: Dictionary = {}
var sold_potions: Dictionary = {}
var customer_results: Dictionary = {}
var discovered_recipes: Array[StringName] = []
var story_flags: Array[StringName] = []


func duplicate_result() -> ShopResult:
	var result := ShopResult.new()
	result.earned_money = earned_money
	result.spent_ingredients = spent_ingredients.duplicate(true)
	result.produced_potions = produced_potions.duplicate(true)
	result.sold_potions = sold_potions.duplicate(true)
	result.customer_results = customer_results.duplicate(true)
	result.discovered_recipes = discovered_recipes.duplicate()
	result.story_flags = story_flags.duplicate()
	return result

