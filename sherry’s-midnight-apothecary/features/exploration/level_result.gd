class_name LevelResult
extends RefCounted

var level_id: StringName
var completed := false
var portal_repaired := false
var collected_items: Dictionary = {}
var completed_puzzles: Array[StringName] = []
var defeated_unique_enemies: Array[StringName] = []
var story_flags: Array[StringName] = []
var remaining_potions: Dictionary = {}


func duplicate_result() -> LevelResult:
	var result := LevelResult.new()
	result.level_id = level_id
	result.completed = completed
	result.portal_repaired = portal_repaired
	result.collected_items = collected_items.duplicate(true)
	result.completed_puzzles = completed_puzzles.duplicate()
	result.defeated_unique_enemies = defeated_unique_enemies.duplicate()
	result.story_flags = story_flags.duplicate()
	result.remaining_potions = remaining_potions.duplicate(true)
	return result

