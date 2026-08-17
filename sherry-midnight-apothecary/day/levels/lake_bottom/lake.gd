class_name LakeLevel
extends DayLevelEnvironment

signal objective_completed(event_id: StringName, payload: Dictionary)
signal level_completed(exit_id: StringName)
signal springburst_changed(charges: int)

@export var local_hud_enabled := true
@export var springburst_initial_charges := 0
@export var purification_hits_required := 3

var springburst_charges: int = 0
var activated_valves: int = 0
var dashiyu_found := false
var tide_eye_defeated := false

@onready var objective_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Objective")
@onready var hint_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Hint")
@onready var charge_label: Label = get_node_or_null("LocalHUD/Panel/VBox/Charges")
@onready var lance: Node = get_node_or_null("BossArena/PurificationLance")
@onready var eye: Node = get_node_or_null("BossArena/TideEye")
@onready var restored_gate: CanvasItem = get_node_or_null("GateZone/GateRestored")
@onready var broken_gate: CanvasItem = get_node_or_null("GateZone/GateBroken")

func _ready() -> void:
    super._ready()
    springburst_charges = springburst_initial_charges
    if get_node_or_null("LocalHUD"):
        $LocalHUD.visible = local_hud_enabled
    if restored_gate:
        restored_gate.visible = false
    if lance and lance.has_method("set_powered"):
        lance.set_powered(false)
    if eye:
        if eye.has_signal("defeated"):
            eye.defeated.connect(_on_tide_eye_defeated)
        if eye.has_method("set_hits_required"):
            eye.set_hits_required(purification_hits_required)
    _set_objective("从涟汀村旧码头下降至阿里特之泪湖床。", "沿旧水位痕迹向湖心探索。")
    _refresh_charges()

# DayRuntime 会在实例化后通过 propagate_call 广播此方法。
func on_level_entered(entry_id: StringName) -> void:
    match String(entry_id):
        "from_gate":
            _set_objective("返回阿里特之泪。", "湖床已经开始重新蓄水。")
        "boss":
            _set_objective("利用涌水诱出噬潮眼。", "待核心张开时操控门泉净化枪。")
        "maintenance":
            _set_objective("调查旧旅门维护站。", "这里居然仍然可以呼吸。")
        _:
            _set_objective("从涟汀村旧码头下降至阿里特之泪湖床。", "寻找大司鱼留下的痕迹。")

func on_dashiyu_found() -> void:
    if dashiyu_found:
        return
    dashiyu_found = true
    _grant_dashiyu_potions(5)
    _refresh_charges()
    _set_objective("大司鱼：拖拽鼠标瞄准投掷青色涌水药水把‘噬潮眼’引出来。", "先启动三座古代泉脉阀，为净化枪供能。")
    _emit_world_event(&"lake_dashiyu_found", {"springburst_charges": springburst_charges})

func _grant_dashiyu_potions(amount: int = 5) -> void:
    springburst_charges = max(springburst_charges, amount)
    var player_data := get_player_data()
    if player_data == null:
        return
    for i in range(amount):
        player_data.add_brewed_potion({
            "potion_id": "cyan_potion",
            "instance_uid": "dashiyu_cyan_%d_%d" % [Time.get_ticks_msec(), i],
            "remaining_dose": 1.0,
            "quality": 1.0,
            "potency": 1.0,
        })
    if not player_data.equipped_potion_ids.has(&"cyan_potion"):
        var equipped := false
        for slot in range(player_data.potion_slot_count):
            if player_data.equipped_potion_ids[slot] == &"":
                player_data.equip_potion(slot, &"cyan_potion")
                player_data.select_potion_slot(slot)
                equipped = true
                break
        if not equipped:
            player_data.equip_potion(0, &"cyan_potion")
            player_data.select_potion_slot(0)

func on_spring_valve_activated(valve_id: StringName) -> void:
    activated_valves += 1
    _emit_world_event(&"lake_valve_activated", {"valve_id": String(valve_id), "count": activated_valves})
    if activated_valves >= 3:
        if lance and lance.has_method("set_powered"):
            lance.set_powered(true)
        _set_objective("净化枪已恢复供能。", "向噬潮眼区域投掷青色药水，核心张开后立刻操控净化枪射击。")
    else:
        _set_objective("恢复古代泉路。", "已启动 %d / 3 座泉脉阀。" % activated_valves)

func can_bait_tide_eye() -> bool:
    return dashiyu_found

func try_bait_with_potion(at_position: Vector2) -> bool:
    if not dashiyu_found:
        _set_hint("先找到旧旅门维护站里的大司鱼。")
        return false
    if eye and eye.has_method("bait_with_water"):
        eye.bait_with_water(at_position)
    on_tide_eye_baited(at_position)
    return true

func on_tide_eye_baited(at_position: Vector2) -> void:
    _refresh_charges()
    _emit_world_event(&"lake_springburst_used", {"position": at_position, "remaining": springburst_charges})

func try_use_springburst(at_position: Vector2) -> bool:
    return try_bait_with_potion(at_position)

func _on_tide_eye_defeated() -> void:
    if tide_eye_defeated:
        return
    tide_eye_defeated = true
    if broken_gate:
        broken_gate.visible = false
    if restored_gate:
        restored_gate.visible = true
    _set_objective("涸泪之灾已被净化。", "地下泉重新涌出；修复沉泪门并返回涟汀村。")
    objective_completed.emit(&"lake_tide_eye_defeated", {"region": "arit_tears"})
    _emit_world_event(&"lake_tide_eye_defeated", {"region": "arit_tears"})

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

func _refresh_charges() -> void:
    var count := springburst_charges
    var player_data := get_player_data()
    if player_data != null:
        var owned := player_data.potion_count(&"cyan_potion")
        if dashiyu_found:
            count = owned
    if charge_label:
        charge_label.text = "涌水药水 × %d" % count
    springburst_changed.emit(count)

func _emit_world_event(event_id: StringName, payload: Dictionary = {}) -> void:
    # 不要求主工程必须拥有 EventBus；存在时才广播。
    var bus := get_node_or_null("/root/EventBus")
    if bus == null:
        return
    if bus.has_signal("level_event"):
        bus.emit_signal("level_event", event_id, payload)
    elif bus.has_method("emit_level_event"):
        bus.call("emit_level_event", event_id, payload)
