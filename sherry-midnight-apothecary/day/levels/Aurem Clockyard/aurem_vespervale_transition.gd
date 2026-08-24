class_name AuremVespervaleTransitionLevel
extends DayLevelEnvironment

signal objective_updated(text: String, hint: String)

const NEXT_LEVEL_ID: StringName = &"vespervale_garden"
const TRANSITION_COMPLETE_FLAG: StringName = &"aurem_vespervale_transition_complete"

@export var finish_x := 2580.0

@onready var player := get_node_or_null("Player") as CharacterBody2D
@onready var luca := get_node_or_null("Luca") as LucaPlayer
@onready var luca_follow := get_node_or_null("LucaFollow") as AuremLucaFollow
@onready var violet_fade := get_node_or_null("VioletFade/ColorRect") as ColorRect

var _finishing := false


func _ready() -> void:
	super._ready()
	if player != null:
		player.call("set_horizontal_input_bounds", 0.0, 1.0)
		player.call("set_potion_action_locked", true)
	if luca != null:
		luca.input_enabled = false
	if luca_follow != null:
		luca_follow.set_follow_enabled(true)
	if violet_fade != null:
		violet_fade.modulate.a = 0.0
	objective_updated.emit("穿过钟庭外缘的旧石道。", "继续向右，前往维斯佩尔眠谷。")


func _physics_process(_delta: float) -> void:
	if not _finishing and player != null and player.global_position.x >= finish_x:
		_finish_transition()


func _finish_transition() -> void:
	if _finishing:
		return
	_finishing = true
	if player != null:
		player.call("set_dialogue_locked", true)
	if luca_follow != null:
		luca_follow.set_follow_enabled(false)
	if violet_fade != null:
		var tween := create_tween()
		tween.tween_property(violet_fade, "modulate:a", 0.82, 0.55)
		await tween.finished
	var runtime := _find_runtime()
	if runtime == null:
		push_error("AuremVespervaleTransitionLevel requires a DayRuntime parent.")
		_finishing = false
		return
	var data := runtime.get_player_data()
	if data != null:
		data.set_event_flag(TRANSITION_COMPLETE_FLAG)
	var result := DayResult.new()
	result.completed = true
	if data != null:
		result.remaining_health = data.health
		result.remaining_potions = data.potions.duplicate(true)
	runtime.finish_day_skipping_night(result, NEXT_LEVEL_ID)


func _find_runtime() -> DayRuntime:
	var current: Node = self
	while current != null:
		if current is DayRuntime:
			return current as DayRuntime
		current = current.get_parent()
	return null


static func expected_walk_seconds(start_x: float = 640.0, target_x: float = 2580.0, speed: float = 50.0) -> float:
	return maxf(target_x - start_x, 0.0) / maxf(speed, 1.0)
