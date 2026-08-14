class_name DayRuntime
extends Node

signal finished(result: DayResult)
signal travel_anchor_activated(level_id: StringName)

const LEVELS: Array[LevelData] = [
	preload("res://day/levels/market/town/town_level.tres"),
	preload("res://day/levels/home/home_level.tres"),
	preload("res://day/levels/home/bedroom_level.tres"),
	preload("res://day/levels/forest/raintree/raintree_level.tres"),
	preload("res://day/levels/lake/lake_level.tres"),
	preload("res://day/levels/grassland/grassland_level.tres"),
	preload("res://day/levels/grassland/emerald_field_level.tres"),
]

# Home is available through its door, but does not consume a day in the normal
# market -> forest -> lake progression.
const DAILY_LEVELS: Array[LevelData] = [
	preload("res://day/levels/market/town/town_level.tres"),
	preload("res://day/levels/forest/raintree/raintree_level.tres"),
	preload("res://day/levels/lake/lake_level.tres"),
]

const SCENE_TITLE_SEEN_PREFIX := "scene_title_seen"

var player_data: PlayerData
var day := 1

@onready var level_slot: Node = $LevelSlot
@onready var gameplay_ui: CanvasLayer = $UI
@onready var scene_title_card: SceneTitleCard = $SceneTitleCard
@onready var developer_console_layer: CanvasLayer = $DeveloperConsoleLayer
@onready var developer_console: Node = $DeveloperConsoleLayer/DeveloperConsole
@onready var level_transition_fade: ColorRect = $LevelTransition/Fade

var current_level: LevelData
var current_level_instance: Node
var _initial_level_id: StringName = &""
var _defer_initial_presentation := false
var _defer_initial_title := false
var _intro_locked := false
var _level_transition_running := false


func get_player_data() -> PlayerData:
	if player_data == null:
		player_data = PlayerData.new()
	return player_data


func configure(
	shared_player_data: PlayerData,
	current_day: int,
	initial_level_id: StringName = &"",
	defer_initial_presentation := false,
	defer_initial_title := false
) -> void:
	player_data = shared_player_data
	day = current_day
	_initial_level_id = initial_level_id
	_defer_initial_presentation = defer_initial_presentation
	_defer_initial_title = defer_initial_title
	_load_level()


func _ready() -> void:
	developer_console.setup_day(self)
	_load_level()


func set_intro_locked(locked: bool) -> void:
	_intro_locked = locked
	if is_node_ready():
		gameplay_ui.visible = not locked
		developer_console_layer.visible = not locked


func _load_level() -> void:
	if not is_inside_tree() or DAILY_LEVELS.is_empty():
		return
	for child in level_slot.get_children():
		child.queue_free()
	current_level = _find_level(_initial_level_id)
	if current_level == null:
		current_level = DAILY_LEVELS[posmod(day, DAILY_LEVELS.size())]
	_sync_bgm_for_current_level()
	_instantiate_current_level(&"default")
	if not _defer_initial_title:
		_play_scene_title_once()
	_initial_level_id = &""
	_defer_initial_presentation = false
	_defer_initial_title = false


func switch_to_level(level_id: String, entry_id: StringName = &"default") -> bool:
	for level_data in LEVELS:
		if str(level_data.id).to_lower() != level_id.to_lower():
			continue
		for child in level_slot.get_children():
			child.queue_free()
		current_level = level_data
		_sync_bgm_for_current_level()
		_instantiate_current_level(entry_id)
		_play_scene_title_once()
		return true
	return false


func transition_to_level_with_blackout(level_id: String, entry_id: StringName = &"default", release_modal_input_lock := false) -> bool:
	if _level_transition_running:
		return false
	_level_transition_running = true
	level_transition_fade.visible = true
	level_transition_fade.modulate.a = 0.0
	var out_tween := create_tween()
	out_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out_tween.tween_property(level_transition_fade, "modulate:a", 1.0, 0.32)
	await out_tween.finished
	var switched := switch_to_level(level_id, entry_id)
	if switched and release_modal_input_lock:
		get_tree().remove_meta("day_modal_input_locked")
	await get_tree().process_frame
	var in_tween := create_tween()
	in_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	in_tween.tween_property(level_transition_fade, "modulate:a", 0.0, 0.32)
	await in_tween.finished
	level_transition_fade.visible = false
	_level_transition_running = false
	return switched


func set_home_destination(level_id: StringName) -> bool:
	if _find_level(level_id) == null:
		return false
	return get_player_data().set_active_home_destination(level_id)


func travel_from_home() -> bool:
	var destination_id := get_player_data().active_home_destination_id
	if not get_player_data().has_unlocked_level(destination_id):
		return false
	return switch_to_level(str(destination_id), &"from_home")


func activate_travel_anchor(level_id: StringName) -> bool:
	if _find_level(level_id) == null:
		return false
	if not get_player_data().unlock_level(level_id):
		return false
	travel_anchor_activated.emit(level_id)
	return true


func _sync_bgm_for_current_level() -> void:
	var sound_manager := get_node_or_null("/root/SoundManager")
	if sound_manager == null:
		return
	if current_level != null and current_level.id in [&"home", &"bedroom"]:
		sound_manager.call("play_day_interior_bgm")
		sound_manager.call("set_day_interior_room_profile")
	else:
		sound_manager.call("stop_bgm")


func _instantiate_current_level(entry_id: StringName) -> Node:
	var level := current_level.content_scene.instantiate()
	var deferred_presentations: Array[AnimationPresentationExecutor] = []
	if _defer_initial_presentation:
		for presentation: Node in level.find_children("*", "AnimationPresentationExecutor", true, false):
			var executor := presentation as AnimationPresentationExecutor
			executor.auto_start = false
			deferred_presentations.append(executor)
	level_slot.add_child(level)
	current_level_instance = level
	for presentation: AnimationPresentationExecutor in deferred_presentations:
		presentation.prepare()
	var entry := level.get_node_or_null("EntryPoints/%s" % entry_id) as Marker2D
	var player := level.get_node_or_null("Player") as CharacterBody2D
	if entry != null and player != null:
		player.global_position = entry.global_position
	level.propagate_call(&"on_level_entered", [entry_id], true)
	return level


func _find_level(level_id: StringName) -> LevelData:
	if level_id == &"":
		return null
	for level_data: LevelData in LEVELS:
		if level_data.id == level_id:
			return level_data
	return null


func replay_scene_title(immediate_text := false) -> bool:
	if current_level == null or not current_level.show_title_card:
		return false
	scene_title_card.show_title(
		day,
		current_level.display_name,
		current_level.title_subtitle_for_environment_state(_current_level_is_corrupted()),
		immediate_text
	)
	return true


func _current_level_is_corrupted() -> bool:
	var environment := current_level_instance as DayLevelEnvironment
	return environment != null and environment.is_corrupted()


func _play_scene_title_once() -> bool:
	if current_level == null or not current_level.show_title_card:
		return false
	var seen_key := scene_title_seen_key(day, current_level.id)
	var data := get_player_data()
	if bool(data.tutorial_flags.get(seen_key, false)):
		return false
	if not replay_scene_title():
		return false
	data.tutorial_flags[seen_key] = true
	return true


static func scene_title_seen_key(day_number: int, level_id: StringName) -> String:
	return "%s:%d:%s" % [SCENE_TITLE_SEEN_PREFIX, maxi(day_number, 1), level_id]


func finish_day(result: DayResult) -> void:
	if result != null:
		finished.emit(result)
