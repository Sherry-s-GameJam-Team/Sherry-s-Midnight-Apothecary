class_name LakeLevel
extends DayLevelEnvironment

signal objective_completed(event_id: StringName, payload: Dictionary)
signal level_completed(exit_id: StringName)

@export var local_hud_enabled := true

var activated_valves := 0
var gate_unlocked := false

@onready var objective_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Objective")
@onready var hint_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Hint")
@onready var maintenance_portal: Node = get_node_or_null("GateZone/MaintenancePortal")
@onready var boss: CanvasItem = get_node_or_null("boss") as CanvasItem
@onready var box_generator: Node = get_node_or_null("boss/BoxGenerator")


func _ready() -> void:
	super._ready()
	if get_node_or_null("LocalHUD"):
		$LocalHUD.visible = local_hud_enabled
	if maintenance_portal and maintenance_portal.has_method("set_portal_active"):
		maintenance_portal.set_portal_active(false)
	_set_boss_phase_visible(false)
	_set_objective("解除沉泪门的三重封印。", "启动散布在湖床上的三座古代泉脉阀。")


# DayRuntime 会在实例化后通过 propagate_call 广播此方法。
func on_level_entered(entry_id: StringName) -> void:
	if entry_id == &"tide_eye_arena":
		_set_boss_phase_visible(true)
		_set_objective("引出噬潮眼。", "投掷涌水药水，利用水脉决定它张口的位置。")
		return
	_set_boss_phase_visible(false)
	if gate_unlocked:
		_set_objective("沉泪门已经开启。", "三重封印已解除。")
	else:
		_set_objective("解除沉泪门的三重封印。", "启动散布在湖床上的三座古代泉脉阀。")


func on_spring_valve_activated(valve_id: StringName) -> void:
	if gate_unlocked:
		return
	activated_valves += 1
	_emit_world_event(&"lake_valve_activated", {"valve_id": String(valve_id), "count": activated_valves})
	if activated_valves >= 3:
		_unlock_gate()
	else:
		_set_objective("解除沉泪门的三重封印。", "已启动 %d / 3 座泉脉阀。" % activated_valves)


func _unlock_gate() -> void:
	if gate_unlocked:
		return
	gate_unlocked = true
	if maintenance_portal and maintenance_portal.has_method("set_portal_active"):
		maintenance_portal.set_portal_active(true)
	_set_objective("维护站传送门已激活。", "前往沉泪门旁，按 E 进入旧旅门维护站。")
	objective_completed.emit(&"lake_gate_unlocked", {"region": "arit_tears"})
	_emit_world_event(&"lake_gate_unlocked", {"region": "arit_tears"})


func complete_level(exit_id: StringName = &"to_village") -> void:
	level_completed.emit(exit_id)
	_emit_world_event(&"lake_level_completed", {"exit_id": String(exit_id)})


func _set_objective(text: String, hint: String = "") -> void:
	if objective_label:
		objective_label.text = text
	_set_hint(hint)


func _set_hint(text: String) -> void:
	if hint_label:
		hint_label.text = text


func _set_boss_phase_visible(active: bool) -> void:
	if boss:
		boss.visible = active
	if box_generator:
		if active and box_generator.has_method("activate"):
			box_generator.activate()
		elif not active and box_generator.has_method("deactivate"):
			box_generator.deactivate()


func _emit_world_event(event_id: StringName, payload: Dictionary = {}) -> void:
	# 不要求主工程必须拥有 EventBus；存在时才广播。
	var bus := get_node_or_null("/root/EventBus")
	if bus == null:
		return
	if bus.has_signal("level_event"):
		bus.emit_signal("level_event", event_id, payload)
	elif bus.has_method("emit_level_event"):
		bus.call("emit_level_event", event_id, payload)
