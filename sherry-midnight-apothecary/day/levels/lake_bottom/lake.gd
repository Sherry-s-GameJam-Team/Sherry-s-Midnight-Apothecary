class_name LakeLevel
extends DayLevelEnvironment

signal objective_completed(event_id: StringName, payload: Dictionary)
signal level_completed(exit_id: StringName)

@export var local_hud_enabled := true

var activated_valves := 0
var gate_unlocked := false
var boss_defeated := false
var boss_phase_active := false

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
	if runtime != null and runtime.get_player_data().has_event_flag(&"lake_bottom_tide_eye_defeated"):
		boss_defeated = true
	if get_node_or_null("LocalHUD"):
		$LocalHUD.visible = local_hud_enabled
	_setup_health_hud(runtime)
	if maintenance_portal and maintenance_portal.has_method("set_portal_active"):
		maintenance_portal.set_portal_active(false)
	if tide_eye != null:
		tide_eye.hit_landed.connect(_on_tide_eye_hit_landed)
		tide_eye.defeated.connect(on_tide_eye_defeated)
	var potion_thrower := get_node_or_null("Player/PotionThrower")
	if potion_thrower != null and potion_thrower.has_signal("projectile_spawned"):
		potion_thrower.connect(&"projectile_spawned", _on_boss_projectile_spawned)
	_set_boss_phase_visible(false)
	_set_objective("解除沉泪门的三重封印。", "启动散布在湖床上的三座古代泉脉阀。")


# DayRuntime 会在实例化后通过 propagate_call 广播此方法。
func on_level_entered(entry_id: StringName) -> void:
	if entry_id == &"tide_eye_arena":
		_set_boss_phase_visible(true)
		_set_objective("引出噬潮眼。", "投掷涌水药水定点引洞；推入焖鱼箱或投净化药水伤害它，别被吞入。")
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
	_set_objective("噬潮眼受创 %d / 3。" % hit_count, "再次投涌水药水引它张口；焖鱼箱或净化药水都能造成伤害。")


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
		runtime.activate_travel_anchor(&"gate_chamber")
	_set_objective("湖水正在回涌。", "和大司鱼一起离开湖底。")
	if task_complete_ui != null:
		task_complete_ui.present(
			"任务完成：平息噬潮眼",
			"阿里特之泪的湖水正在回到湖床，大司鱼终于能回家了。",
			"按任意确认键继续"
		)
		await task_complete_ui.dismissed
	if epilogue != null:
		epilogue.play()


func _on_boss_projectile_spawned(projectile: PotionProjectile) -> void:
	projectile.broken.connect(_on_boss_potion_broken.bind(projectile), CONNECT_ONE_SHOT)


func _on_boss_potion_broken(impact_point: Vector2, impact_normal: Vector2, projectile: PotionProjectile) -> void:
	if not boss_phase_active or tide_eye == null or projectile.potion == null:
		return
	# A floor collision has an upward-facing normal. This intentionally ignores
	# bottles that strike a target or pass through the arena before landing.
	if projectile.potion.id == &"cyan_potion" and impact_normal.y < -0.55:
		tide_eye.bait_with_water(impact_point)


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
