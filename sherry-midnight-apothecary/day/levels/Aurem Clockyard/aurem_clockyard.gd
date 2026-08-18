class_name AuremClockyardLevel
extends DayLevelEnvironment

signal objective_updated(text: String, hint: String)
signal farm_cleansed
signal clocktower_synchronized

@export var is_tower_synchronized := false
@export var fall_damage: int = 1

@onready var farm_normal: Sprite2D = get_node_or_null("Background/CS/Farm/FarmNormal") if get_node_or_null("Background/CS/Farm/FarmNormal") != null else get_node_or_null("World/Farm/FarmNormal")
@onready var farm_corrupted: Sprite2D = get_node_or_null("Background/CS/Farm/FarmCorrupted") if get_node_or_null("Background/CS/Farm/FarmCorrupted") != null else get_node_or_null("World/Farm/FarmCorrupted")
@onready var entrance_portal: DoorPortal = get_node_or_null("World/Portals/EntrancePortal")
@onready var tower_portal: DoorPortal = get_node_or_null("World/Portals/TowerPortal")
@onready var tower_exit_portal: DoorPortal = get_node_or_null("World/Portals/TowerExitPortal")
@onready var abyss_hazard: Area2D = get_node_or_null("World/AbyssHazard")
@onready var clockmaker_npc: Area2D = get_node_or_null("World/NPCs/Clockmaker")

var _last_checkpoint_pos: Vector2 = Vector2(300, 520)
var _is_respawning: bool = false


func _ready() -> void:
	super._ready()
	_update_visual_states()
	_setup_abyss_hazard()
	_setup_npc()


func on_level_entered(entry_id: StringName) -> void:
	match String(entry_id):
		"from_tower", "tower_inner":
			_last_checkpoint_pos = Vector2(6700, 520)
			objective_updated.emit("深入奥伦巨钟塔内部。", "检查巨型擒纵轮与时律中枢。")
		"tower":
			_last_checkpoint_pos = Vector2(4900, 520)
			objective_updated.emit("抵达奥伦巨钟塔前庭。", "寻找进入时律核心的枢纽界门。")
		"farm":
			_last_checkpoint_pos = Vector2(2000, 520)
			objective_updated.emit("探索金穗农庄。", "清除侵蚀齿轮灌溉渠的锈蚀浊气。")
		_:
			_last_checkpoint_pos = Vector2(300, 520)
			objective_updated.emit("踏入奥伦钟庭。", "沿着齿轮石道向东探索金穗农庄与巨钟塔。")


func set_corrupted(corrupted: bool) -> void:
	super.set_corrupted(corrupted)
	_update_visual_states()


func set_farm_cleansed(cleansed: bool) -> void:
	set_corrupted(not cleansed)
	if cleansed:
		farm_cleansed.emit()
		var data := get_player_data()
		if data != null and data.tutorial_flags != null:
			data.tutorial_flags["aurem_clockyard_farm_cleansed"] = true


func set_tower_synchronized(synchronized: bool) -> void:
	is_tower_synchronized = synchronized
	if synchronized:
		clocktower_synchronized.emit()
		var data := get_player_data()
		if data != null and data.tutorial_flags != null:
			data.tutorial_flags["aurem_clockyard_tower_synchronized"] = true


func _update_visual_states() -> void:
	var corrupted := is_corrupted() or start_corrupted
	var normal_spr := farm_normal if farm_normal != null else (get_node_or_null("Background/CS/Farm/FarmNormal") as Sprite2D if get_node_or_null("Background/CS/Farm/FarmNormal") != null else get_node_or_null("World/Farm/FarmNormal") as Sprite2D)
	var corrupted_spr := farm_corrupted if farm_corrupted != null else (get_node_or_null("Background/CS/Farm/FarmCorrupted") as Sprite2D if get_node_or_null("Background/CS/Farm/FarmCorrupted") != null else get_node_or_null("World/Farm/FarmCorrupted") as Sprite2D)

	if normal_spr != null:
		normal_spr.visible = not corrupted
	if corrupted_spr != null:
		corrupted_spr.visible = corrupted


func _setup_abyss_hazard() -> void:
	if abyss_hazard != null and not abyss_hazard.body_entered.is_connected(_on_abyss_body_entered):
		abyss_hazard.body_entered.connect(_on_abyss_body_entered)


func _setup_npc() -> void:
	if clockmaker_npc != null and not clockmaker_npc.body_entered.is_connected(_on_npc_body_entered):
		clockmaker_npc.body_entered.connect(_on_npc_body_entered)
	if clockmaker_npc != null and not clockmaker_npc.body_exited.is_connected(_on_npc_body_exited):
		clockmaker_npc.body_exited.connect(_on_npc_body_exited)


func _on_npc_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", "aurem_npc", "按 E 与钟庭工匠对话")


func _on_npc_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("hide_interaction_hint"):
			top_hint.call("hide_interaction_hint", "aurem_npc")


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	return null


func _on_abyss_body_entered(body: Node2D) -> void:
	if _is_respawning:
		return
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		_is_respawning = true
		var death_handled := apply_player_damage(fall_damage, &"aurem_abyss_fall")
		if not death_handled:
			body.global_position = _last_checkpoint_pos
			if body.has_method("reset_physics_interpolation"):
				body.call("reset_physics_interpolation")
			var tree := get_tree()
			if tree != null:
				await tree.create_timer(0.5).timeout
		_is_respawning = false
