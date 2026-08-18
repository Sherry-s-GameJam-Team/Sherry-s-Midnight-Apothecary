class_name VespervaleGardenLevel
extends DayLevelEnvironment

## Daytime Vespervale Garden level.
## Features the Twilight Garden and Silent Sanctuary without repeating scroll backgrounds.

signal objective_updated(text: String, hint: String)
signal garden_cleansed
signal dream_awakened

@export var is_garden_purified := false
@export var fall_damage: int = 1

@onready var real_garden: Sprite2D = get_node_or_null("Background/GardenAtmosphere/RealGarden")
@onready var dream_garden: Sprite2D = get_node_or_null("Background/GardenAtmosphere/DreamGarden")
@onready var entrance_portal: DoorPortal = get_node_or_null("World/Portals/EntrancePortal")
@onready var church_portal: DoorPortal = get_node_or_null("World/Portals/ChurchPortal")
@onready var abyss_hazard: Area2D = get_node_or_null("World/AbyssHazard")
@onready var sleep_npcs: Area2D = get_node_or_null("World/NPCs/SleepNpcs")

var _last_checkpoint_pos: Vector2 = Vector2(250, 520)
var _is_respawning: bool = false


func _ready() -> void:
	super._ready()
	_update_visual_states()
	_setup_abyss_hazard()
	_setup_npc_interaction()


func on_level_entered(entry_id: StringName) -> void:
	match String(entry_id):
		"church":
			_last_checkpoint_pos = Vector2(4800, 520)
			objective_updated.emit("抵达静语礼堂前庭。", "观察沉睡的旅人并寻找唤醒梦魇的调和药剂。")
		"garden":
			_last_checkpoint_pos = Vector2(2400, 520)
			objective_updated.emit("漫步于暮息庭院。", "调查梦境侵蚀的花架与沉睡植株。")
		_:
			_last_checkpoint_pos = Vector2(250, 520)
			objective_updated.emit("踏入暮息庭院。", "沿着暮光石径向东探索梦息花园与静语礼堂。")


func set_corrupted(corrupted: bool) -> void:
	super.set_corrupted(corrupted)
	_update_visual_states()


func set_garden_purified(purified: bool) -> void:
	is_garden_purified = purified
	set_corrupted(not purified)
	if purified:
		garden_cleansed.emit()
		var data := get_player_data()
		if data != null and data.tutorial_flags != null:
			data.tutorial_flags["vespervale_garden_cleansed"] = true


func _update_visual_states() -> void:
	var corrupted := is_corrupted() or (start_corrupted and not is_garden_purified)
	var real_spr := real_garden if real_garden != null else get_node_or_null("Background/GardenAtmosphere/RealGarden") as Sprite2D
	var dream_spr := dream_garden if dream_garden != null else get_node_or_null("Background/GardenAtmosphere/DreamGarden") as Sprite2D

	if real_spr != null:
		real_spr.visible = not corrupted
	if dream_spr != null:
		dream_spr.visible = corrupted


func _setup_abyss_hazard() -> void:
	if abyss_hazard != null and not abyss_hazard.body_entered.is_connected(_on_abyss_body_entered):
		abyss_hazard.body_entered.connect(_on_abyss_body_entered)


func _setup_npc_interaction() -> void:
	if sleep_npcs != null:
		if not sleep_npcs.body_entered.is_connected(_on_npc_body_entered):
			sleep_npcs.body_entered.connect(_on_npc_body_entered)
		if not sleep_npcs.body_exited.is_connected(_on_npc_body_exited):
			sleep_npcs.body_exited.connect(_on_npc_body_exited)


func _on_npc_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", "vespervale_sleep_npc", "按 E 观察沉睡的旅人")


func _on_npc_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("hide_interaction_hint"):
			top_hint.call("hide_interaction_hint", "vespervale_sleep_npc")


func _on_abyss_body_entered(body: Node2D) -> void:
	if _is_respawning:
		return
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		_is_respawning = true
		apply_player_damage(fall_damage, &"vespervale_abyss")
		body.global_position = _last_checkpoint_pos
		if body.has_method("set_velocity"):
			body.call("set_velocity", Vector2.ZERO)
		var timer := get_tree().create_timer(0.3)
		timer.timeout.connect(func(): _is_respawning = false)


func _find_top_hint() -> Node:
	var local_hint := get_node_or_null("GlobalUI/TopHintUI")
	if local_hint != null:
		return local_hint
	var runtime := get_parent()
	if runtime != null and runtime.has_node("TopHintUI"):
		return runtime.get_node("TopHintUI")
	return get_tree().root.find_child("TopHintUI", true, false)
