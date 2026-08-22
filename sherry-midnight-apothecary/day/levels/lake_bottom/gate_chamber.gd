class_name GateChamberLevel
extends DayLevelEnvironment

@export var local_hud_enabled := true

const DASHIYU_COMPLETED_FLAG := &"lake_bottom_dashiyu_dialogue_completed"
const DASHIYU_TASK_ID := &"lake_bottom_dashiyu"
const TIDE_EYE_TASK_ID := &"lake_bottom_tide_eye"

@onready var objective_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Objective")
@onready var hint_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Hint")

func _ready() -> void:
	super._ready()
	if get_node_or_null("LocalHUD"):
		$LocalHUD.visible = local_hud_enabled
	_register_day_two_task()
	_set_objective("旧旅门维护站内部", "通过中央门返回阿里特之泪湖床。")

func on_level_entered(_entry_id: StringName) -> void:
	_set_objective("旧旅门维护站内部", "通过中央门返回阿里特之泪湖床。")


func on_dashiyu_dialogue_completed() -> void:
	_set_objective("前往阿里特之泪湖床。", "涌水药水已加入背包；准备引出噬潮眼。")
	var player_data := get_player_data()
	if player_data != null:
		player_data.set_active_daily_task(TIDE_EYE_TASK_ID, "引出噬潮眼", _current_day())
	var hint := get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	if hint != null:
		hint.push_text("涌水药水已作为攻击性药水加入到背包", "dashiyu_springburst_reward", 4.0)


func _register_day_two_task() -> void:
	var player_data := get_player_data()
	if player_data == null or _current_day() != 2 or player_data.has_event_flag(DASHIYU_COMPLETED_FLAG):
		return
	player_data.set_active_daily_task(DASHIYU_TASK_ID, "与大司鱼交谈", 2)


func _current_day() -> int:
	var current: Node = self
	while current != null:
		if current.has_method("switch_to_level") and current.has_method("get_player_data"):
			return int(current.get("day"))
		current = current.get_parent()
	return -1

func _set_objective(text: String, hint: String = "") -> void:
	if objective_label:
		objective_label.text = text
	if hint_label:
		hint_label.text = hint
