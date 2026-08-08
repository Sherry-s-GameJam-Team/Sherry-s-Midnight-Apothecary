class_name DayRuntime
extends Node

signal finished(result: DayResult)

var player_data: PlayerData
var day := 1

const LEVELS: Array[LevelData] = [
	preload("res://day/levels/market/town/town_level.tres"),
	preload("res://day/levels/home/home_level.tres"),
	preload("res://day/levels/forest/raintree/raintree_level.tres"),
	preload("res://day/levels/lake/lake_level.tres"),
]

# Home is available through its door, but does not consume a day in the normal
# market → forest → lake progression.
const DAILY_LEVELS: Array[LevelData] = [
	preload("res://day/levels/market/town/town_level.tres"),
	preload("res://day/levels/forest/raintree/raintree_level.tres"),
	preload("res://day/levels/lake/lake_level.tres"),
]

@onready var level_slot: Node = $LevelSlot
@onready var level_title: Label = $UI/LevelTitle
@onready var finish_button: Button = $UI/FinishDayButton
@onready var scene_title_card: SceneTitleCard = $SceneTitleCard
@onready var developer_console: Node = $UI/DeveloperConsole

var current_level: LevelData


func get_player_data() -> PlayerData:
	if player_data == null:
		player_data = PlayerData.new()
	return player_data


func configure(shared_player_data: PlayerData, current_day: int) -> void:
	player_data = shared_player_data
	day = current_day
	_load_level()


func _ready() -> void:
	finish_button.pressed.connect(_finish_current_level)
	developer_console.setup_day(self)
	_load_level()


func _unhandled_input(event: InputEvent) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return
	if event.is_action_pressed("ui_accept"):
		_finish_current_level()
		get_viewport().set_input_as_handled()


func _load_level() -> void:
	if not is_node_ready() or DAILY_LEVELS.is_empty():
		return
	for child in level_slot.get_children():
		child.queue_free()
	current_level = DAILY_LEVELS[posmod(day - 1, DAILY_LEVELS.size())]
	_instantiate_current_level(&"default")
	scene_title_card.show_title(
		day,
		current_level.display_name,
		current_level.disaster_name,
		current_level.scene_description
	)
	level_title.text = "Day %d · %s" % [day, current_level.display_name]


func _finish_current_level() -> void:
	var result := DayResult.new()
	result.completed = true
	if player_data != null:
		result.remaining_health = player_data.health
		result.remaining_potions = player_data.potions.duplicate(true)
	finish_day(result)


func switch_to_level(level_id: String, entry_id: StringName = &"default") -> bool:
	for level_data in LEVELS:
		if str(level_data.id).to_lower() != level_id.to_lower():
			continue
		for child in level_slot.get_children():
			child.queue_free()
		current_level = level_data
		_instantiate_current_level(entry_id)
		level_title.text = "Day %d 路 %s" % [day, current_level.display_name]
		replay_scene_title()
		return true
	return false


func _instantiate_current_level(entry_id: StringName) -> Node:
	var level := current_level.content_scene.instantiate()
	level_slot.add_child(level)
	var entry := level.get_node_or_null("EntryPoints/%s" % entry_id) as Marker2D
	var player := level.get_node_or_null("Player") as CharacterBody2D
	if entry != null and player != null:
		player.global_position = entry.global_position
	return level


func replay_scene_title() -> void:
	if current_level == null:
		return
	scene_title_card.show_title(
		day,
		current_level.display_name,
		current_level.disaster_name,
		current_level.scene_description
	)


func finish_day(result: DayResult) -> void:
	if result != null:
		finished.emit(result)
