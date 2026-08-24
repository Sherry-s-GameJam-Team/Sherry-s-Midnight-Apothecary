class_name LakeLevel
extends DayLevelEnvironment

const SpringburstProgression := preload("res://day/levels/lake_bottom/scripts/springburst_potion_progression.gd")

signal objective_completed(event_id: StringName, payload: Dictionary)
signal level_completed(exit_id: StringName)

@export var local_hud_enabled := true

var activated_valves := 0
var gate_unlocked := false
var boss_defeated := false
var boss_phase_active := false
var _boss_phase_generation := 0
var _auto_open_pending := false

@export var auto_eye_open_position := Vector2(7460.0, 890.0)
@export_range(0.2, 5.0, 0.1) var auto_eye_open_delay := 1.6

@onready var objective_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Objective")
@onready var hint_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Hint")
@onready var maintenance_portal: Node = get_node_or_null("GateZone/MaintenancePortal")
@onready var box_generator: Node = get_node_or_null("boss/BoxGenerator")
@onready var dashiyu_boss_sprite: CanvasItem = get_node_or_null("boss/Dashiyu") as CanvasItem
@onready var tide_eye: TideEye = get_node_or_null("boss/TideEye") as TideEye
@onready var epilogue: LakeBossEpilogue = get_node_or_null("boss/Epilogue") as LakeBossEpilogue
@onready var local_health_hud: PlayerHealthHUD = get_node_or_null("LocalHealthHUD/PlayerHealthHUD") as PlayerHealthHUD
@onready var task_complete_ui: TaskCompleteUI = get_node_or_null("TaskCompleteUI") as TaskCompleteUI


func _ready() -> void:
	super._ready()
	var runtime := _find_day_runtime()
	if runtime != null:
		var player_data: PlayerData = runtime.get_player_data()
		if player_data.has_event_flag(&"lake_bottom_tide_eye_defeated"):
			boss_defeated = true
			SpringburstProgression.enforce_story_item_phase(player_data)
			SpringburstProgression.unlock_throwable_after_boss(player_data)
		else:
			SpringburstProgression.enforce_story_item_phase(player_data)
	if get_node_or_null("LocalHUD"):
		$LocalHUD.visible = local_hud_enabled
	_setup_health_hud(runtime)
	if maintenance_portal and maintenance_portal.has_method("set_portal_active"):
		maintenance_portal.set_portal_active(false)
	if tide_eye != null:
		tide_eye.hit_landed.connect(_on_tide_eye_hit_landed)
		tide_eye.defeated.connect(on_tide_eye_defeated)
		tide_eye.exposed_changed.connect(_on_tide_eye_exposed_changed)
	_set_boss_phase_visible(false)
	_set_objective("解除沉泪门的三重封印。", "启动散布在湖床上的三座古代泉脉阀。")


# DayRuntime 会在实例化后通过 propagate_call 广播此方法。
func on_level_entered(entry_id: StringName) -> void:
	if entry_id == &"tide_eye_arena":
		_set_boss_phase_visible(true)
		_set_objective("等待噬潮眼现身。", "泉脉会让它周期性张开；趁机推入焖鱼箱或投净化药水，别被吞入。")
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
	for valve in $ValvePuzzle.get_children():
		if valve.has_method("set_interaction_enabled"):
			valve.set_interaction_enabled(false)
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
	_boss_phase_generation += 1
	_auto_open_pending = false
	if dashiyu_boss_sprite:
		dashiyu_boss_sprite.visible = active and not boss_defeated
	if boss_defeated:
		return
	boss_phase_active = active
	# Static boss-support art keeps the visibility and Transform authored in the
	# editor. Runtime state only enables the procedural eye and its gameplay.
	if tide_eye:
		if active:
			tide_eye.activate()
			_schedule_auto_eye_open(_boss_phase_generation)
		else:
			tide_eye.deactivate()
	if box_generator:
		if active and box_generator.has_method("activate"):
			# Start every arena entry with a fresh box set; no dynamic box survives
			# from a previous encounter in the same runtime.
			if box_generator.has_method("deactivate"):
				box_generator.deactivate()
			box_generator.activate()
		elif not active and box_generator.has_method("deactivate"):
			box_generator.deactivate()


func _on_tide_eye_hit_landed(hit_count: int) -> void:
	_set_objective("噬潮眼受创 %d / 3。" % hit_count, "等待它再次现身；焖鱼箱或净化药水都能造成伤害。")


func _on_tide_eye_exposed_changed(is_exposed: bool) -> void:
	if not is_exposed and boss_phase_active and not boss_defeated:
		_schedule_auto_eye_open(_boss_phase_generation)


func _schedule_auto_eye_open(generation: int) -> void:
	if _auto_open_pending or not boss_phase_active or boss_defeated or tide_eye == null:
		return
	_auto_open_pending = true
	await get_tree().create_timer(auto_eye_open_delay).timeout
	_auto_open_pending = false
	if generation != _boss_phase_generation or not boss_phase_active or boss_defeated or tide_eye == null:
		return
	tide_eye.bait_with_water(auto_eye_open_position)


func on_tide_eye_defeated() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	boss_phase_active = false
	if dashiyu_boss_sprite:
		dashiyu_boss_sprite.visible = false
	if box_generator and box_generator.has_method("deactivate"):
		box_generator.deactivate()
	var runtime := _find_day_runtime()
	if runtime != null:
		var player_data: PlayerData = runtime.get_player_data() as PlayerData
		if player_data != null:
			player_data.set_event_flag(&"lake_bottom_tide_eye_defeated")
			var unlocked_count := SpringburstProgression.unlock_throwable_after_boss(player_data)
			var hint := get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
			if hint != null and unlocked_count > 0:
				hint.push_text("涌水药水已解锁为投掷药水\n共 %d 瓶" % unlocked_count, "springburst_throwable_unlocked", 5.0)
		runtime.activate_travel_anchor(&"gate_chamber")
	_set_objective("湖水正在回涌。", "涌水药水已解锁投掷用途；和大司鱼一起离开湖底。")
	if task_complete_ui != null:
		task_complete_ui.present(
			"任务完成：平息噬潮眼",
			"阿里特之泪的湖水正在回到湖床，大司鱼终于能回家了。",
			"按任意确认键继续"
		)
		await task_complete_ui.dismissed
	if epilogue != null:
		epilogue.play()


func _setup_health_hud(runtime: Node) -> void:
	# Lake Bottom owns a reliable scene-local health display. It binds to the
	# same PlayerData as DayRuntime, while the generic HUD stays hidden here so
	# another runtime UI state cannot suppress or duplicate the bar.
	if runtime != null:
		runtime.set_health_hud_visible(false)
	if local_health_hud != null:
		local_health_hud.bind_player_data(get_player_data())
		local_health_hud.visible = true


func _exit_tree() -> void:
	var runtime := _find_day_runtime()
	if runtime != null:
		runtime.set_health_hud_visible(true)


func _find_day_runtime() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("get_player_data") and current.has_method("activate_travel_anchor"):
			return current
		current = current.get_parent()
	return null


func _emit_world_event(event_id: StringName, payload: Dictionary = {}) -> void:
	# 不要求主工程必须拥有 EventBus；存在时才广播。
	var bus := get_node_or_null("/root/EventBus")
	if bus == null:
		return
	if bus.has_signal("level_event"):
		bus.emit_signal("level_event", event_id, payload)
	elif bus.has_method("emit_level_event"):
		bus.call("emit_level_event", event_id, payload)
