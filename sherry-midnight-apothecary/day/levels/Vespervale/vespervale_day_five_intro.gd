class_name VespervaleDayFiveIntro
extends Node2D

## Day-five first-arrival dream presentation in Vespervale Garden.
## It owns only local staging; persistent day/task state remains in DayRuntime
## and PlayerData.

const REQUIRED_DAY := 5
const COMPLETE_FLAG: StringName = &"vespervale_day_five_first_path_complete"
const TASK_ID: StringName = &"vespervale_first_path"
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const DialoguePortraitDatabase := preload("res://night/dialogue/portrait_database.gd")

enum Stage {
	INACTIVE,
	READY,
	AUTO_WALK,
	RIGHT_ONLY,
	BRIDGE_DIALOGUE,
	COMPLETE,
}

@export var dialogue_resource: DialogueResource
@export var serena_portrait: Texture2D
@export var auto_walk_speed := 145.0
@export var bridge_trigger_offset := 215.0

@onready var _player := get_node_or_null("../Player") as CharacterBody2D
@onready var _walk_start := get_node_or_null("walkstart") as Marker2D
@onready var _walk_end := get_node_or_null("walkend") as Marker2D
@onready var _serena := get_node_or_null("SerenaIllusion") as Sprite2D
@onready var _luca_proxy := get_node_or_null("LucaProxy") as Sprite2D

var _stage := Stage.INACTIVE
var _bridge_trigger_x := 0.0
var _minimum_progress_x := 0.0
var _ending_requested := false
var _portal_monitoring: Dictionary = {}


func _ready() -> void:
	if serena_portrait != null:
		DialoguePortraitDatabase.register_portrait("塞蕾娜", "default", serena_portrait)
		DialoguePortraitDatabase.register_portrait("Serena", "default", serena_portrait)
	if _serena != null:
		_serena.visible = false
	if _luca_proxy != null:
		_luca_proxy.visible = false
	var active := should_present(_current_day(), _player_data())
	visible = active
	_stage = Stage.READY if active else Stage.INACTIVE
	set_physics_process(active)


func begin_for_entry(entry_id: StringName) -> void:
	if _stage != Stage.READY or String(entry_id) not in ["", "default", "from_home"]:
		return
	call_deferred("_begin_sequence")


func _physics_process(_delta: float) -> void:
	if _stage != Stage.RIGHT_ONLY or _player == null:
		return
	if _player.global_position.x < _minimum_progress_x:
		_player.global_position.x = _minimum_progress_x
	else:
		_minimum_progress_x = _player.global_position.x
	if _player.global_position.x >= _bridge_trigger_x:
		_stage = Stage.BRIDGE_DIALOGUE
		_player.call("set_horizontal_input_bounds", 0.0, 0.0)
		call_deferred("_play_bridge_dialogue")


func _begin_sequence() -> void:
	if _stage != Stage.READY or _player == null or _walk_start == null or _walk_end == null:
		return
	_stage = Stage.AUTO_WALK
	_set_portals_enabled(false)
	_player.global_position.x = _walk_start.global_position.x
	_player.call("set_horizontal_input_bounds", 0.0, 0.0)
	_player.call("set_dialogue_locked", true)
	_player.call("set_potion_action_locked", true)
	_player.call("_update_facing", 1.0)
	_player.call("_play", "walk")
	var distance := absf(_walk_end.global_position.x - _player.global_position.x)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(_player, "global_position:x", _walk_end.global_position.x, distance / maxf(auto_walk_speed, 1.0))
	await tween.finished
	if not is_instance_valid(_player):
		return
	_player.call("_play", "idle")
	await _play_dialogue(&"start")
	if _stage == Stage.COMPLETE or not is_instance_valid(_player):
		return
	_minimum_progress_x = _player.global_position.x
	_bridge_trigger_x = _serena.global_position.x - bridge_trigger_offset if _serena != null else _minimum_progress_x + 250.0
	_stage = Stage.RIGHT_ONLY
	_player.call("set_dialogue_locked", false)
	_player.call("set_potion_action_locked", false)
	_player.call("set_horizontal_input_bounds", 0.0, 1.0)
	var hint := _find_top_hint()
	if hint != null:
		hint.push_text("梦雾中只能继续向右。", "vespervale_right_only", 3.0)


func _play_bridge_dialogue() -> void:
	_show_serena_illusion()
	await _play_dialogue(&"bridge")
	if _ending_requested:
		_finish_event()
	elif _stage != Stage.COMPLETE and is_instance_valid(_player):
		_stage = Stage.RIGHT_ONLY
		_player.call("set_horizontal_input_bounds", 0.0, 1.0)


func _play_dialogue(title: StringName) -> void:
	if dialogue_resource == null:
		push_error("VespervaleDayFiveIntro requires its dialogue resource.")
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager") as Node
	if dialogue_manager == null or not dialogue_manager.has_method("show_dialogue_balloon_scene"):
		push_error("VespervaleDayFiveIntro requires the DialogueManager autoload.")
		return
	var balloon := dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, title) as Node
	if balloon == null:
		return
	if balloon.has_signal("dialogue_event"):
		balloon.dialogue_event.connect(_on_dialogue_event)
	await balloon.tree_exited


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	match event_name:
		&"vespervale_serena_reveal":
			_show_serena_illusion()
		&"vespervale_luca_pull":
			_play_luca_pull()
		&"vespervale_serena_distort":
			_distort_serena_illusion()
		&"vespervale_serena_dissolve":
			_dissolve_serena_illusion()
		&"vespervale_first_path":
			_ending_requested = true


func _show_serena_illusion() -> void:
	if _serena == null or _serena.visible:
		return
	_serena.visible = true
	_serena.modulate = Color(0.76, 0.64, 1.0, 0.0)
	create_tween().tween_property(_serena, "modulate:a", 0.92, 0.8)


func _play_luca_pull() -> void:
	if _player == null:
		return
	if _luca_proxy != null:
		_luca_proxy.visible = true
		_luca_proxy.global_position = _player.global_position + Vector2(-75.0, 18.0)
	var pull_target := _player.global_position.x - 65.0
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_player, "global_position:x", pull_target, 0.28)
	_distort_serena_illusion()


func _distort_serena_illusion() -> void:
	if _serena == null or not _serena.visible:
		return
	var tween := create_tween()
	for offset in [Vector2(7, -2), Vector2(-6, 3), Vector2(5, 1), Vector2.ZERO]:
		tween.tween_property(_serena, "position", _serena.position + offset, 0.06)


func _dissolve_serena_illusion() -> void:
	if _serena == null or not _serena.visible:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_serena, "modulate", Color(0.49, 0.22, 0.72, 0.0), 0.7)
	tween.tween_property(_serena, "scale", _serena.scale * 1.12, 0.7)


func _finish_event() -> void:
	if _stage == Stage.COMPLETE:
		return
	_stage = Stage.COMPLETE
	set_physics_process(false)
	if _serena != null:
		_serena.visible = false
	if _player != null:
		_player.call("set_horizontal_input_bounds", -1.0, 1.0)
		_player.call("set_dialogue_locked", false)
		_player.call("set_potion_action_locked", false)
	_set_portals_enabled(true)
	var data := _player_data()
	if data != null:
		data.set_event_flag(COMPLETE_FLAG)
		data.set_active_daily_task(TASK_ID, "跟随卢卡寻找真实道路，调查维斯佩尔眠谷的异常。", REQUIRED_DAY)
	var level := get_parent()
	if level != null and level.has_signal("objective_updated"):
		level.emit_signal("objective_updated", "主线任务：未醒之谷", "跟随卢卡寻找真实道路，调查维斯佩尔眠谷的异常。")


func _set_portals_enabled(enabled: bool) -> void:
	var portals := get_node_or_null("../World/Portals")
	if portals == null:
		return
	for child in portals.get_children():
		var area := child as Area2D
		if area == null:
			continue
		if not _portal_monitoring.has(area):
			_portal_monitoring[area] = area.monitoring
		area.monitoring = bool(_portal_monitoring.get(area, true)) if enabled else false


func _current_day() -> int:
	var runtime := _find_runtime()
	return runtime.day if runtime != null else -1


func _player_data() -> PlayerData:
	var runtime := _find_runtime()
	return runtime.get_player_data() if runtime != null else null


func _find_runtime() -> DayRuntime:
	var current: Node = get_parent()
	while current != null:
		if current is DayRuntime:
			return current
		current = current.get_parent()
	return null


func _find_top_hint() -> TopHintUI:
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI


static func should_present(current_day: int, player_data: PlayerData) -> bool:
	return current_day == REQUIRED_DAY and (player_data == null or not player_data.has_event_flag(COMPLETE_FLAG))
