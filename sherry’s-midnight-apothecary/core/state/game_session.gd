class_name GameSession
extends RefCounted

const SAVE_VERSION := 1

var _current_day: int = 1
var current_day: int:
	get:
		return _current_day

var current_phase: int = 0
var money: int = 0
var debt: int = 0
var inventory: Dictionary = {}
var owned_potions: Dictionary = {}
var unlocked_levels: Array[StringName] = []
var repaired_portals: Array[StringName] = []
var restored_regions: Array[StringName] = []
var completed_puzzles: Array[StringName] = []
var customer_relationships: Dictionary = {}
var story_flags: Array[StringName] = []
var disaster_states: Dictionary = {}
var player_upgrades: Dictionary = {}


func _init() -> void:
	reset_to_new_game()


func reset_to_new_game() -> void:
	_current_day = 1
	current_phase = 0
	money = 0
	debt = 0
	inventory = {}
	owned_potions = {}
	unlocked_levels = []
	repaired_portals = []
	restored_regions = []
	completed_puzzles = []
	customer_relationships = {}
	story_flags = []
	disaster_states = {}
	player_upgrades = {}


## Internal flow boundary. GameFlow is the only production caller.
func _set_current_day_from_flow(day: int) -> void:
	_current_day = maxi(day, 1)


func to_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"current_day": _current_day,
		"current_phase": current_phase,
		"money": money,
		"debt": debt,
		"inventory": inventory.duplicate(true),
		"owned_potions": owned_potions.duplicate(true),
		"unlocked_levels": unlocked_levels.duplicate(),
		"repaired_portals": repaired_portals.duplicate(),
		"restored_regions": restored_regions.duplicate(),
		"completed_puzzles": completed_puzzles.duplicate(),
		"customer_relationships": customer_relationships.duplicate(true),
		"story_flags": story_flags.duplicate(),
		"disaster_states": disaster_states.duplicate(true),
		"player_upgrades": player_upgrades.duplicate(true),
	}


static func from_save_data(data: Dictionary) -> GameSession:
	var result := GameSession.new()
	result._current_day = maxi(int(data.get("current_day", 1)), 1)
	result.current_phase = int(data.get("current_phase", 0))
	result.money = int(data.get("money", 0))
	result.debt = int(data.get("debt", 0))
	result.inventory = _dictionary_copy(data.get("inventory", {}))
	result.owned_potions = _dictionary_copy(data.get("owned_potions", {}))
	result.unlocked_levels = _string_name_array(data.get("unlocked_levels", []))
	result.repaired_portals = _string_name_array(data.get("repaired_portals", []))
	result.restored_regions = _string_name_array(data.get("restored_regions", []))
	result.completed_puzzles = _string_name_array(data.get("completed_puzzles", []))
	result.customer_relationships = _dictionary_copy(data.get("customer_relationships", {}))
	result.story_flags = _string_name_array(data.get("story_flags", []))
	result.disaster_states = _dictionary_copy(data.get("disaster_states", {}))
	result.player_upgrades = _dictionary_copy(data.get("player_upgrades", {}))
	return result


static func _dictionary_copy(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			result.append(StringName(str(item)))
	return result

