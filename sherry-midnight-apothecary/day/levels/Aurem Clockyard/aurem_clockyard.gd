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
@onready var herb_director: HerbSpawnDirector = get_node_or_null("HerbSpawnDirector")
@onready var post_boss_sequence: AuremPostBossSequence = get_node_or_null("PostBossSequence")

const TASK_COMPLETE_UI_SCENE := preload("res://day/ui/task_complete/task_complete_ui.tscn")

var _last_checkpoint_pos: Vector2 = Vector2(300, 520)
var _is_respawning: bool = false
var _victory_presented: bool = false


func _ready() -> void:
	super._ready()
	_check_victory_state()
	_configure_post_boss_herbs()
	_update_visual_states()
	_setup_abyss_hazard()


func _check_victory_state() -> void:
	var data := get_player_data()
	if data != null and data.tutorial_flags != null:
		if data.tutorial_flags.get("aurem_helion_cleared", false) or data.tutorial_flags.get("aurem_clockyard_tower_synchronized", false):
			is_tower_synchronized = true
			set_corrupted(false)


func on_level_entered(entry_id: StringName) -> void:
	match String(entry_id):
		"from_tower", "tower_inner":
			_last_checkpoint_pos = Vector2(6700, 520)
			var data := get_player_data()
			var cleared: bool = data != null and data.tutorial_flags != null and (data.tutorial_flags.get("aurem_helion_cleared", false) or data.tutorial_flags.get("aurem_clockyard_tower_synchronized", false))
			if cleared:
				is_tower_synchronized = true
				set_corrupted(false)
				objective_updated.emit("奥勒姆钟庭时律已恢复正常。", "与钟表匠交谈，或通过界门返回雪莉药水铺。")
				if not _victory_presented:
					_victory_presented = true
					call_deferred("_present_victory_ui")
			else:
				objective_updated.emit("深入奥勒姆巨钟塔内部。", "检查巨型擒纵轮与时律中枢。")
		"tower":
			_last_checkpoint_pos = Vector2(4900, 520)
			objective_updated.emit("抵达奥勒姆巨钟塔前庭。", "寻找进入时律核心的枢纽界门。")
		"farm":
			_last_checkpoint_pos = Vector2(2000, 520)
			objective_updated.emit("探索金穗农庄。", "清除侵蚀齿轮灌溉渠的锈蚀浊气。")
		_:
			_last_checkpoint_pos = Vector2(300, 520)
			objective_updated.emit("踏入奥勒姆钟庭。", "沿着齿轮石道向东探索金穗农庄与巨钟塔。")
	if post_boss_sequence != null:
		post_boss_sequence.begin_for_entry(entry_id)


func _configure_post_boss_herbs() -> void:
	if herb_director == null:
		return
	var data := get_player_data()
	herb_director.set_spawning_enabled(AuremPostBossSequence.should_spawn_post_boss_herbs(data))


func _present_victory_ui() -> void:
	var ui := TASK_COMPLETE_UI_SCENE.instantiate() as CanvasLayer
	if ui != null:
		add_child(ui)
		if ui.has_method("present"):
			ui.call("present", "奥勒姆钟庭·时律重构完成", "十二刻守望者·赫利昂已平息，中央巨钟塔与金穗农庄时律已彻底恢复正常。")


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
	var corrupted := is_corrupted() or (start_corrupted and not is_tower_synchronized)
	var data := get_player_data()
	if data != null and data.tutorial_flags != null:
		if data.tutorial_flags.get("aurem_helion_cleared", false) or data.tutorial_flags.get("aurem_clockyard_farm_cleansed", false) or data.tutorial_flags.get("aurem_clockyard_tower_synchronized", false):
			corrupted = false

	var normal_spr := farm_normal if farm_normal != null else (get_node_or_null("Background/CS/Farm/FarmNormal") as Sprite2D if get_node_or_null("Background/CS/Farm/FarmNormal") != null else get_node_or_null("World/Farm/FarmNormal") as Sprite2D)
	var corrupted_spr := farm_corrupted if farm_corrupted != null else (get_node_or_null("Background/CS/Farm/FarmCorrupted") as Sprite2D if get_node_or_null("Background/CS/Farm/FarmCorrupted") != null else get_node_or_null("World/Farm/FarmCorrupted") as Sprite2D)

	if normal_spr != null:
		normal_spr.visible = not corrupted
	if corrupted_spr != null:
		corrupted_spr.visible = corrupted

	# Clockmaker (清道机·柒号) disappears in normal state, only active when corrupted
	var clockmaker: Node = get_node_or_null("World/NPCs/Clockmaker")
	if clockmaker != null:
		if clockmaker.has_method("set_active"):
			clockmaker.call("set_active", corrupted)
		else:
			clockmaker.set("visible", corrupted)

	# Daily NPCs appear when in normal / cleansed state
	var daily_npcs: Node = get_node_or_null("World/NPCs/DailyNPCs")
	if daily_npcs != null:
		daily_npcs.set("visible", not corrupted)
		for child: Node in daily_npcs.get_children():
			if child.has_method("set_active"):
				child.call("set_active", not corrupted)


func _setup_abyss_hazard() -> void:
	if abyss_hazard != null and not abyss_hazard.body_entered.is_connected(_on_abyss_body_entered):
		abyss_hazard.body_entered.connect(_on_abyss_body_entered)


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
