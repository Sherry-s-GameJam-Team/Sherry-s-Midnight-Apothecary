class_name AuremPostBossSequence
extends Node2D

const BOSS_CLEARED_FLAG: StringName = &"aurem_helion_cleared"
const HARVEST_DIALOGUE_COMPLETE_FLAG: StringName = &"aurem_post_boss_harvest_complete"
const ROAD_LOOP_SEEN_FLAG: StringName = &"aurem_clockyard_road_loop_seen"
const TRANSITION_LEVEL_ID: StringName = &"aurem_vespervale_transition"
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const DialoguePortraitDatabase := preload("res://night/dialogue/portrait_database.gd")

@export var dialogue_resource: DialogueResource
@export var serena_portrait: Texture2D
@export var route_trigger_x := 7900.0
@export var loop_distance := 500.0

@onready var _level := get_parent() as AuremClockyardLevel
@onready var _player := get_node_or_null("../Player") as CharacterBody2D
@onready var _luca := get_node_or_null("../Luca") as LucaPlayer
@onready var _luca_follow := get_node_or_null("../LucaFollow") as AuremLucaFollow
@onready var _herb_director := get_node_or_null("../HerbSpawnDirector") as HerbSpawnDirector
@onready var _lamp := get_node_or_null("VioletRoadLamp") as Node2D
@onready var _serena := get_node_or_null("SerenaGlimpse") as Sprite2D
@onready var _violet_veil := get_node_or_null("VioletVeil/ColorRect") as ColorRect
@onready var _audio := get_node_or_null("../ClocktowerAudio") as ClocktowerAudio

var _route_ready := false
var _dialogue_active := false
var _loop_anchor_x := 0.0
var _transition_requested := false


func _ready() -> void:
	if serena_portrait != null:
		DialoguePortraitDatabase.register_portrait("塞蕾娜", "default", serena_portrait)
		DialoguePortraitDatabase.register_portrait("Serena", "default", serena_portrait)
	if _herb_director != null and not _herb_director.herb_collected.is_connected(_on_herb_collected):
		_herb_director.herb_collected.connect(_on_herb_collected)
	if _lamp != null:
		_lamp.visible = false
	if _serena != null:
		_serena.visible = false
	if _violet_veil != null:
		_violet_veil.modulate.a = 0.0
	set_physics_process(false)


func begin_for_entry(_entry_id: StringName) -> void:
	var data := _player_data()
	var boss_cleared := data != null and data.has_event_flag(BOSS_CLEARED_FLAG)
	var dialogue_complete := data != null and data.has_event_flag(HARVEST_DIALOGUE_COMPLETE_FLAG)
	if _herb_director != null:
		_herb_director.set_spawning_enabled(boss_cleared and not dialogue_complete)
	_set_luca_present(boss_cleared)
	if not boss_cleared:
		return
	if dialogue_complete:
		_enable_route()
		return
	call_deferred("_resume_harvest_objective")


func _resume_harvest_objective() -> void:
	if _herb_director == null:
		return
	var collected := _herb_director.collected_point_count()
	var total := _herb_director.spawn_point_count()
	if total > 0 and collected >= total:
		_play_harvest_dialogue()
	else:
		_show_harvest_hint(collected, total)


func _on_herb_collected(_ingredient_id: StringName, _amount: int, _point_name: StringName) -> void:
	if _herb_director == null or _dialogue_active:
		return
	var collected := _herb_director.collected_point_count()
	var total := _herb_director.spawn_point_count()
	if total > 0 and collected >= total:
		call_deferred("_play_harvest_dialogue")
	else:
		_show_harvest_hint(collected, total)


func _play_harvest_dialogue() -> void:
	if _dialogue_active or dialogue_resource == null:
		return
	var data := _player_data()
	if data != null and data.has_event_flag(HARVEST_DIALOGUE_COMPLETE_FLAG):
		_enable_route()
		return
	_dialogue_active = true
	_set_story_controls_locked(true)
	var balloon := _show_dialogue(&"harvest_complete")
	if balloon != null:
		await balloon.tree_exited
	if data != null:
		data.set_event_flag(HARVEST_DIALOGUE_COMPLETE_FLAG)
	_dialogue_active = false
	_set_story_controls_locked(false)
	_enable_route()


func _physics_process(_delta: float) -> void:
	if not _route_ready or _dialogue_active or _transition_requested or _player == null:
		return
	if _player.global_position.x >= route_trigger_x:
		_request_transition()
		return
	var data := _player_data()
	if data != null and not data.has_event_flag(ROAD_LOOP_SEEN_FLAG) and _player.global_position.x <= _loop_anchor_x - loop_distance:
		_play_road_loop()


func _play_road_loop() -> void:
	if _dialogue_active or _player == null:
		return
	_dialogue_active = true
	_set_story_controls_locked(true)
	await _flash_violet()
	_player.global_position = Vector2(route_trigger_x - 160.0, _player.global_position.y)
	if _luca != null:
		_luca.global_position = _player.global_position + Vector2(-150.0, 0.0)
	var balloon := _show_dialogue(&"road_loop")
	if balloon != null:
		await balloon.tree_exited
	var data := _player_data()
	if data != null:
		data.set_event_flag(ROAD_LOOP_SEEN_FLAG)
	_dialogue_active = false
	_set_story_controls_locked(false)
	_show_text_hint("返回钟庭的路已闭合。沿右侧紫色路灯前往维斯佩尔。", "aurem_road_closed", 5.0)


func _enable_route() -> void:
	_route_ready = true
	_loop_anchor_x = _player.global_position.x if _player != null else 0.0
	_set_portals_enabled(false)
	if _lamp != null:
		_lamp.visible = true
	set_physics_process(true)
	_show_text_hint("调查右侧亮起紫光的旧石道。", "aurem_vespervale_road", 5.0)


func _request_transition() -> void:
	_transition_requested = true
	_set_story_controls_locked(true)
	await _flash_violet()
	var runtime := _find_runtime()
	if runtime != null:
		runtime.switch_to_level(str(TRANSITION_LEVEL_ID), &"default")
		get_tree().remove_meta("day_modal_input_locked")


func _show_dialogue(title: StringName) -> Node:
	var dialogue_manager := get_node_or_null("/root/DialogueManager") as Node
	if dialogue_manager == null or not dialogue_manager.has_method("show_dialogue_balloon_scene"):
		push_error("AuremPostBossSequence requires the DialogueManager autoload.")
		return null
	var balloon := dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, title) as Node
	if balloon != null and balloon.has_signal("dialogue_event"):
		balloon.dialogue_event.connect(_on_dialogue_event)
	return balloon


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	match event_name:
		&"aurem_clockyard_normal_chimes":
			_play_normal_chimes()
		&"aurem_distant_toll_1", &"aurem_distant_toll_2", &"aurem_distant_toll_3":
			if _audio != null:
				_audio.play_grand_synchronization_toll()
		&"aurem_luca_face_right":
			if _luca != null:
				_luca.call("_update_facing", 1.0)
		&"aurem_violet_lamp_on":
			if _lamp != null:
				_lamp.visible = true
			_reveal_violet_veil()
		&"aurem_serena_glimpse":
			_show_serena_glimpse()
		&"aurem_serena_hide":
			_hide_serena_glimpse()


func _play_normal_chimes() -> void:
	if _audio == null:
		return
	_audio.play_bell_warning(false)
	await get_tree().create_timer(0.75).timeout
	if is_instance_valid(_audio):
		_audio.play_bell_warning(false)


func _show_serena_glimpse() -> void:
	if _serena == null or _player == null:
		return
	_serena.global_position = _player.global_position + Vector2(620.0, -8.0)
	_serena.visible = true
	_serena.modulate = Color(0.7, 0.54, 0.92, 0.0)
	create_tween().tween_property(_serena, "modulate:a", 0.55, 0.45)


func _hide_serena_glimpse() -> void:
	if _serena == null or not _serena.visible:
		return
	var tween := create_tween()
	tween.tween_property(_serena, "modulate:a", 0.0, 0.35)
	tween.finished.connect(func() -> void:
		if is_instance_valid(_serena):
			_serena.visible = false
	, CONNECT_ONE_SHOT)


func _reveal_violet_veil() -> void:
	if _violet_veil != null:
		create_tween().tween_property(_violet_veil, "modulate:a", 0.18, 1.2)


func _flash_violet() -> void:
	if _violet_veil == null:
		return
	var prior_alpha := _violet_veil.modulate.a
	var tween := create_tween()
	tween.tween_property(_violet_veil, "modulate:a", 0.72, 0.16)
	tween.tween_property(_violet_veil, "modulate:a", prior_alpha, 0.28)
	await tween.finished


func _set_story_controls_locked(locked: bool) -> void:
	if _player != null:
		_player.call("set_dialogue_locked", locked)
		_player.call("set_potion_action_locked", locked)
	if _luca_follow != null:
		_luca_follow.set_follow_enabled(not locked)
	if _luca != null and locked:
		_luca.stop_moving()
	if locked:
		get_tree().set_meta("day_modal_input_locked", true)
	else:
		get_tree().remove_meta("day_modal_input_locked")


func _set_luca_present(present: bool) -> void:
	if _luca != null:
		_luca.visible = present
		_luca.input_enabled = false
		if present and _player != null and _luca.global_position == Vector2.ZERO:
			_luca.global_position = _player.global_position + Vector2(-150.0, 0.0)
	if _luca_follow != null:
		_luca_follow.set_follow_enabled(present and not _dialogue_active)


func _set_portals_enabled(enabled: bool) -> void:
	var portals := get_node_or_null("../World/Portals")
	if portals == null:
		return
	for child: Node in portals.get_children():
		var portal := child as Area2D
		if portal != null:
			portal.monitoring = enabled
			portal.set_process_input(enabled)


func _show_harvest_hint(collected: int, total: int) -> void:
	_show_text_hint("前往金穗农庄机械大棚，收集恢复后的作物（%d/%d）" % [collected, total], "aurem_post_boss_harvest", 5.0)
	if _level != null:
		_level.objective_updated.emit("收集钟庭恢复后的作物。", "前往金穗农庄机械大棚（%d/%d）。" % [collected, total])


func _show_text_hint(text: String, hint_id: String, seconds: float) -> void:
	var top_hint := get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	if top_hint != null:
		top_hint.push_text(text, hint_id, seconds)


func _player_data() -> PlayerData:
	return _level.get_player_data() if _level != null else null


func _find_runtime() -> DayRuntime:
	var current: Node = _level
	while current != null:
		if current is DayRuntime:
			return current as DayRuntime
		current = current.get_parent()
	return null
