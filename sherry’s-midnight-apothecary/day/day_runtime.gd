class_name DayRuntime
extends Node

signal finished(result: DayResult)

var player_data: PlayerData
var day := 1

const LEVELS: Array[LevelData] = [
	preload("res://day/levels/market/town/town_level.tres"),
	preload("res://day/levels/forest/raintree/raintree_level.tres"),
	preload("res://day/levels/lake/lake_level.tres"),
]

@onready var level_slot: Node = $LevelSlot
@onready var level_title: Label = $UI/LevelTitle
@onready var finish_button: Button = $UI/FinishDayButton

var current_level: LevelData


func configure(shared_player_data: PlayerData, current_day: int) -> void:
	player_data = shared_player_data
	day = current_day
	_load_level()


func _ready() -> void:
	finish_button.pressed.connect(_finish_current_level)
	_load_level()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_finish_current_level()
		get_viewport().set_input_as_handled()


func _load_level() -> void:
	if not is_node_ready() or LEVELS.is_empty():
		return
	for child in level_slot.get_children():
		child.queue_free()
	current_level = LEVELS[posmod(day - 1, LEVELS.size())]
	var level = current_level.content_scene.instantiate()
	level_slot.add_child(level)
	level_title.text = "Day %d · %s" % [day, current_level.display_name]


func _finish_current_level() -> void:
	var result := DayResult.new()
	result.completed = true
	finish_day(result)


func finish_day(result: DayResult) -> void:
	if result != null:
		finished.emit(result)
