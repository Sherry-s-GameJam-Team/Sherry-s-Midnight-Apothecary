extends Node2D

@export var medicine_max := 100.0
@export var overheat_max := 100.0
@export var corruption_max := 100.0
@export var camera_pan_x := 240.0
@export var camera_pan_y := 110.0

var medicine := medicine_max
var overheat := 0.0
var corruption := 0.0
var power_level := 1
var scanning := false
var scan_time := 0.0
var cleared: Array[String] = []
var order := ["A", "B", "C", "MOTHER"]
var finished := false
var resetting := false

@onready var camera: Camera2D = $Camera2D
@onready var roots: Node2D = $World/Roots
@onready var medicine_bar: ProgressBar = $UI/MedicineBar
@onready var heat_bar: ProgressBar = $UI/HeatBar
@onready var corruption_bar: ProgressBar = $UI/CorruptionBar
@onready var power_label: Label = $UI/PowerLabel
@onready var objective_label: Label = $UI/Objective
@onready var hint_label: Label = $UI/Hint
@onready var fade: ColorRect = $UI/Fade
@onready var success_panel: Panel = $UI/SuccessPanel

func _ready() -> void:
    for child in roots.get_children():
        if child is MiasmaRoot:
            child.purified.connect(_on_root_purified)
    _set_mother_active(false)
    _update_ui()
    hint_label.text = "鼠标移动观察 · 左键净化 · 右键探脉 · 滚轮切换功率 · R重置"

func _process(delta: float) -> void:
    if resetting or finished:
        return
    _update_camera()
    _handle_scan(delta)
    _handle_purify(delta)
    overheat = max(0.0, overheat - 24.0 * delta)
    corruption += _ambient_corruption_rate() * delta
    if corruption >= corruption_max:
        _fail_and_reset()
    _update_ui()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            power_level = min(3, power_level + 1)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            power_level = max(1, power_level - 1)
    if event.is_action_pressed("reset_minigame"):
        get_tree().reload_current_scene()

func _update_camera() -> void:
    var vp := get_viewport_rect().size
    var mouse := get_viewport().get_mouse_position()
    var norm := Vector2(
        clamp((mouse.x / vp.x - 0.5) * 2.0, -1.0, 1.0),
        clamp((mouse.y / vp.y - 0.5) * 2.0, -1.0, 1.0)
    )
    camera.position = Vector2(norm.x * camera_pan_x, norm.y * camera_pan_y)

func _handle_scan(delta: float) -> void:
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        scanning = true
        scan_time = 1.0
    if scan_time > 0.0:
        scan_time -= delta
        for child in roots.get_children():
            if child is MiasmaRoot:
                child.set_highlighted(child.active)
    elif scanning:
        scanning = false
        for child in roots.get_children():
            if child is MiasmaRoot:
                child.set_highlighted(false)

func _handle_purify(delta: float) -> void:
    if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        return
    if medicine <= 0.0 or overheat >= overheat_max:
        return
    medicine = max(0.0, medicine - (5.0 + 2.0 * power_level) * delta)
    overheat = min(overheat_max, overheat + (13.0 + 7.0 * power_level) * delta)

    var target := _root_under_mouse()
    if target == null:
        return
    var expected := _expected_root_id()
    if target.root_id != expected:
        corruption = min(corruption_max, corruption + 13.0 * delta)
        objective_label.text = "风向错序：先净化上风口 %s" % expected
        return
    var success := target.apply_purification((18.0 + 9.0 * power_level) * delta, power_level)
    if not success:
        overheat = min(overheat_max, overheat + 10.0 * delta)
        objective_label.text = "%s 需要功率 %d" % [target.root_id, target.required_power]

func _root_under_mouse() -> MiasmaRoot:
    var pos := get_global_mouse_position()
    var query := PhysicsPointQueryParameters2D.new()
    query.position = pos
    query.collide_with_areas = true
    query.collide_with_bodies = false
    var hits := get_world_2d().direct_space_state.intersect_point(query, 16)
    for hit in hits:
        var collider = hit.get("collider")
        if collider is MiasmaRoot:
            return collider
    return null

func _expected_root_id() -> String:
    return order[min(cleared.size(), order.size() - 1)]

func _on_root_purified(root_id: String) -> void:
    if root_id not in cleared:
        cleared.append(root_id)
    if cleared.size() == 3:
        _set_mother_active(true)
        objective_label.text = "次级瘴根已清除：切换高功率净化母根"
    elif root_id == "MOTHER":
        _success()
    else:
        objective_label.text = "顺风净化：下一目标 %s" % _expected_root_id()

func _set_mother_active(value: bool) -> void:
    var mother := roots.get_node_or_null("MotherRoot") as MiasmaRoot
    if mother:
        mother.active = value
        mother.visible = value

func _ambient_corruption_rate() -> float:
    var active_count := 0
    for child in roots.get_children():
        if child is MiasmaRoot and child.active and not child.permanently_cleared:
            active_count += 1
    return 0.45 * active_count

func _success() -> void:
    finished = true
    success_panel.visible = true
    objective_label.text = "翡翠原瘴气已净化"
    for p in $World/WindParticles.get_children():
        if p is GPUParticles2D:
            p.emitting = false

func _fail_and_reset() -> void:
    if resetting:
        return
    resetting = true
    var tween := create_tween()
    tween.tween_property(fade, "color:a", 1.0, 0.35)
    tween.tween_interval(0.25)
    tween.tween_callback(func(): get_tree().reload_current_scene())

func _update_ui() -> void:
    medicine_bar.value = medicine
    heat_bar.value = overheat
    corruption_bar.value = corruption
    power_label.text = "净化功率：%d" % power_level
    if not finished and objective_label.text.is_empty():
        objective_label.text = "顺风净化：目标 %s" % _expected_root_id()
