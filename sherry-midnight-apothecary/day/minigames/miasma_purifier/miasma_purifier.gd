class_name MiasmaPurifier
extends Node2D

signal succeeded
signal cancelled

const ORDER: Array[String] = ["A", "B", "C", "MOTHER"]

var medicine := 100.0
var overheat := 0.0
var corruption := 0.0
var power_level := 1
var cleared: Array[String] = []
var _finished := false

@onready var camera: Camera2D = $Camera2D
@onready var roots: Node2D = $World/Roots
@onready var medicine_bar: ProgressBar = $UI/MedicineBar
@onready var heat_bar: ProgressBar = $UI/HeatBar
@onready var corruption_bar: ProgressBar = $UI/CorruptionBar
@onready var power_label: Label = $UI/PowerLabel
@onready var objective_label: Label = $UI/Objective
@onready var success_panel: Panel = $UI/SuccessPanel
@onready var fail_panel: Panel = $UI/FailPanel


func _ready() -> void:
	camera.make_current()
	for child: Node in roots.get_children():
		var root: MiasmaPurifierRoot = child as MiasmaPurifierRoot
		if root != null:
			root.purified.connect(_on_root_purified)
	_set_mother_active(false)
	_update_ui()


func _process(delta: float) -> void:
	if _finished:
		return
	_update_camera()
	_handle_scan()
	_handle_purify(delta)
	overheat = maxf(0.0, overheat - 24.0 * delta)
	corruption = minf(100.0, corruption + _ambient_corruption_rate() * delta)
	if corruption >= 100.0:
		_fail_and_reset()
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			power_level = mini(3, power_level + 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			power_level = maxi(1, power_level - 1)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reset()


func _update_camera() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var target: Vector2 = Vector2(
		clampf((mouse.x / viewport_size.x - 0.5) * 2.0, -1.0, 1.0) * 560.0,
		clampf((mouse.y / viewport_size.y - 0.5) * 2.0, -1.0, 1.0) * 270.0
	)
	camera.position = target


func _handle_scan() -> void:
	var scanning: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	for child: Node in roots.get_children():
		var root: MiasmaPurifierRoot = child as MiasmaPurifierRoot
		if root != null:
			root.set_highlighted(scanning and root.active)


func _handle_purify(delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or medicine <= 0.0 or overheat >= 100.0:
		return
	medicine = maxf(0.0, medicine - (5.0 + 2.0 * power_level) * delta)
	overheat = minf(100.0, overheat + (13.0 + 7.0 * power_level) * delta)
	var target: MiasmaPurifierRoot = _root_under_mouse()
	if target == null:
		return
	var expected: String = ORDER[mini(cleared.size(), ORDER.size() - 1)]
	if target.root_id != expected:
		corruption = minf(100.0, corruption + 13.0 * delta)
		objective_label.text = "风向错误：先净化 %s" % expected
		return
	if not target.apply_purification((18.0 + 9.0 * power_level) * delta, power_level):
		overheat = minf(100.0, overheat + 10.0 * delta)
		objective_label.text = "%s 需要功率 %d" % [target.root_id, target.required_power]


func _root_under_mouse() -> MiasmaPurifierRoot:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_point(query, 16):
		var root: MiasmaPurifierRoot = hit.get("collider") as MiasmaPurifierRoot
		if root != null:
			return root
	return null


func _on_root_purified(root_id: String) -> void:
	if root_id not in cleared:
		cleared.append(root_id)
	if root_id == "MOTHER":
		_success()
	elif cleared.size() == 3:
		_set_mother_active(true)
		objective_label.text = "根系已净化：切换至功率 3 净化母根"
	else:
		objective_label.text = "顺风净化：下一目标 %s" % ORDER[cleared.size()]


func _set_mother_active(value: bool) -> void:
	var mother: MiasmaPurifierRoot = roots.get_node_or_null("MotherRoot") as MiasmaPurifierRoot
	if mother != null:
		mother.active = value
		mother.visible = value


func _ambient_corruption_rate() -> float:
	var active_count: int = 0
	for child: Node in roots.get_children():
		var root: MiasmaPurifierRoot = child as MiasmaPurifierRoot
		if root != null and root.active and not root.permanently_cleared:
			active_count += 1
	return 0.45 * active_count


func _success() -> void:
	_finished = true
	success_panel.visible = true
	objective_label.text = "翡翠原瘴气已净化"
	await get_tree().create_timer(1.1).timeout
	succeeded.emit()


func _fail_and_reset() -> void:
	_finished = true
	fail_panel.visible = true
	await get_tree().create_timer(0.7).timeout
	_reset()


func _reset() -> void:
	medicine = 100.0
	overheat = 0.0
	corruption = 0.0
	power_level = 1
	cleared.clear()
	_finished = false
	success_panel.visible = false
	fail_panel.visible = false
	for child: Node in roots.get_children():
		var root: MiasmaPurifierRoot = child as MiasmaPurifierRoot
		if root == null:
			continue
		root.health = root.max_health
		root.permanently_cleared = false
		root.active = root.root_id != "MOTHER"
		root.visible = root.active
		root.fog.emitting = root.active
		root._refresh_visual()
	_update_ui()


func _update_ui() -> void:
	medicine_bar.value = medicine
	heat_bar.value = overheat
	corruption_bar.value = corruption
	power_label.text = "净化功率：%d" % power_level
	if not _finished and objective_label.text.is_empty():
		objective_label.text = "顺风净化：目标 %s" % ORDER[cleared.size()]
