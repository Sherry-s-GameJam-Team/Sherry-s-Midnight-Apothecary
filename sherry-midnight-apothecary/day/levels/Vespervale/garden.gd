class_name VespervaleGardenLevel
extends DayLevelEnvironment

## Daytime Vespervale Garden level.
## Features the Twilight Garden and Silent Sanctuary without repeating scroll backgrounds.

signal objective_updated(text: String, hint: String)
signal garden_cleansed
signal dream_awakened

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var is_garden_purified := false
@export var fall_damage: int = 1
@export var sleep_npc_dialogue: DialogueResource = preload("res://day/levels/Vespervale/vespervale_sleep_npc.dialogue")

@onready var real_garden: Sprite2D = get_node_or_null("Background/GardenAtmosphere/RealGarden")
@onready var dream_garden: Sprite2D = get_node_or_null("Background/GardenAtmosphere/DreamGarden")
@onready var entrance_portal: DoorPortal = get_node_or_null("World/Portals/EntrancePortal")
@onready var church_portal: DoorPortal = get_node_or_null("World/Portals/ChurchPortal")
@onready var abyss_hazard: Area2D = get_node_or_null("World/AbyssHazard")
@onready var sleep_npcs: Area2D = get_node_or_null("World/NPCs/SleepNpcs")
@onready var day_five_intro: VespervaleDayFiveIntro = get_node_or_null("IssueDay5") as VespervaleDayFiveIntro

var _last_checkpoint_pos: Vector2 = Vector2(250, 520)
var _is_respawning: bool = false
var _player_in_npc_area: bool = false
var _dialogue_active: bool = false


func _ready() -> void:
	super._ready()
	_update_visual_states()
	_setup_abyss_hazard()
	_setup_npc_interaction()
	_sync_cleared_state()

	var top_hint := _find_top_hint()
	if top_hint != null and top_hint.has_method("hide_interaction_hint"):
		top_hint.call("hide_interaction_hint", "vespervale_sleep_npc")


func on_level_entered(entry_id: StringName) -> void:
	_player_in_npc_area = false
	var top_hint := _find_top_hint()
	if top_hint != null and top_hint.has_method("hide_interaction_hint"):
		top_hint.call("hide_interaction_hint", "vespervale_sleep_npc")

	_sync_cleared_state()

	var data := get_player_data()
	var boss_cleared := false
	if data != null and data.tutorial_flags != null:
		boss_cleared = bool(data.tutorial_flags.get("vespervale_boss_cleared", false)) or bool(data.tutorial_flags.get("vespervale_garden_cleansed", false))

	if boss_cleared:
		_last_checkpoint_pos = Vector2(3160, 520)
		objective_updated.emit("维斯佩尔梦疗院已净化！", "梦境消散，沉睡者已苏醒。前往左侧传送门返回药水铺开启晚间营业。")
	else:
		match String(entry_id):
			"church":
				_last_checkpoint_pos = Vector2(3160, 520)
				objective_updated.emit("抵达静语礼堂前庭。", "观察沉睡的旅人并寻找唤醒梦魇的调和药剂。")
			"garden":
				_last_checkpoint_pos = Vector2(2400, 520)
				objective_updated.emit("漫步于暮息庭院。", "调查梦境侵蚀的花架与沉睡植株。")
			_:
				_last_checkpoint_pos = Vector2(250, 520)
				objective_updated.emit("踏入暮息庭院。", "沿着暮光石径向东探索梦息花园与静语礼堂。")
	if day_five_intro != null:
		day_five_intro.begin_for_entry(entry_id)


func _sync_cleared_state() -> void:
	var data := get_player_data()
	var boss_cleared := false
	if data != null and data.tutorial_flags != null:
		boss_cleared = bool(data.tutorial_flags.get("vespervale_boss_cleared", false)) or bool(data.tutorial_flags.get("vespervale_garden_cleansed", false))

	if boss_cleared:
		is_garden_purified = true
		_update_visual_states()
		# Hide all NPCs in garden
		var npcs_node := get_node_or_null("World/NPCs")
		if npcs_node != null:
			npcs_node.visible = false
			for child in npcs_node.get_children():
				if child is Area2D:
					child.monitoring = false
					child.collision_mask = 0
		_player_in_npc_area = false
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("hide_interaction_hint"):
			top_hint.call("hide_interaction_hint", "vespervale_sleep_npc")

	if entrance_portal != null and entrance_portal.has_method("update_portal_state"):
		entrance_portal.call("update_portal_state")


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
	var corrupted := not is_garden_purified
	if real_garden != null:
		real_garden.visible = not corrupted
	if dream_garden != null:
		dream_garden.visible = corrupted


func _setup_abyss_hazard() -> void:
	if abyss_hazard != null and not abyss_hazard.body_entered.is_connected(_on_abyss_body_entered):
		abyss_hazard.body_entered.connect(_on_abyss_body_entered)


func _setup_npc_interaction() -> void:
	if sleep_npcs != null:
		if not sleep_npcs.body_entered.is_connected(_on_npc_body_entered):
			sleep_npcs.body_entered.connect(_on_npc_body_entered)
		if not sleep_npcs.body_exited.is_connected(_on_npc_body_exited):
			sleep_npcs.body_exited.connect(_on_npc_body_exited)


func _input(event: InputEvent) -> void:
	if _dialogue_active or not _player_in_npc_area:
		return
	if get_tree().has_meta("day_modal_input_locked"):
		return

	if _is_interact_event(event):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		_start_sleep_npc_dialogue()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E or key_event.key_label == KEY_E
	)


func _start_sleep_npc_dialogue() -> void:
	if sleep_npc_dialogue == null:
		return
	_dialogue_active = true

	# Lock player during dialogue
	var player := get_node_or_null("Player")
	if player != null:
		if player.has_method("set_dialogue_locked"):
			player.call("set_dialogue_locked", true)
		elif player.has_method("set_control_enabled"):
			player.call("set_control_enabled", false)

	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager != null and dialogue_manager.has_method("show_dialogue_balloon_scene"):
		dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, sleep_npc_dialogue, &"start")
		if dialogue_manager.has_signal("dialogue_ended"):
			dialogue_manager.dialogue_ended.connect(_on_sleep_dialogue_ended, CONNECT_ONE_SHOT)
		else:
			_on_sleep_dialogue_ended()
	else:
		_on_sleep_dialogue_ended()


func _on_sleep_dialogue_ended(_resource: Resource = null) -> void:
	_dialogue_active = false
	var player := get_node_or_null("Player")
	if player != null:
		if player.has_method("set_dialogue_locked"):
			player.call("set_dialogue_locked", false)
		elif player.has_method("set_control_enabled"):
			player.call("set_control_enabled", true)


func _on_npc_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		_player_in_npc_area = true
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", "vespervale_sleep_npc", "按 E 观察沉睡的旅人")


func _on_npc_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		_player_in_npc_area = false
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
