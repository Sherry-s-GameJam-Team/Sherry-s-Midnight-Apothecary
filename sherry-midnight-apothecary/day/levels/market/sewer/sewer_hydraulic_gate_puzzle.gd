class_name SewerHydraulicGatePuzzle
extends Node2D

## Local state owner for the sewer hydraulic lock. All presentation lives in
## editable scene children; this script never draws puzzle UI or geometry.
signal pressure_changed(pressure: int)
signal status_changed(message: String)
signal unlocked

enum Valve { RED, BLUE, YELLOW, GREEN }

const TARGET_PRESSURE := 7
const MAX_SAFE_PRESSURE := 8

@export var player_path: NodePath
@export var gate_path: NodePath
@export var direction_up_texture: Texture2D
@export var direction_down_texture: Texture2D
## The source pointer art faces roughly -45 degrees at zero Sprite2D rotation.
## Keep this editor-adjustable if the pointer crop/offset is retuned.
@export var pointer_art_angle := -0.78

var pressure := 0
var red_uses := 0
var blue_uses := 0
var yellow_uses := 0
var flow_down := false
var is_unlocked := false
var is_open := false
var _operation_history: Array[int] = []
var _player: CharacterBody2D
var _status := "主闸锁死：校准至 7.0 巴"


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_update_presentation()


func try_interact(valve: int) -> bool:
	use_valve(valve)
	return true


func use_valve(valve: int) -> void:
	match valve:
		Valve.RED:
			_use_pressure_valve(Valve.RED, 4)
		Valve.BLUE:
			if red_uses == 0:
				_set_status_with_hint("必须先开启红色主供水阀。")
				return
			_use_pressure_valve(Valve.BLUE, 3)
		Valve.YELLOW:
			if blue_uses == 0:
				_set_status_with_hint("必须先以蒸汽升温。")
				return
			_use_pressure_valve(Valve.YELLOW, -1)
		Valve.GREEN:
			flow_down = not flow_down
			_set_status("换向阀：%s" % ("顺流（下）" if flow_down else "逆流（上）"))
			_evaluate_unlock()
	_update_presentation()


func _use_pressure_valve(valve: int, amount: int) -> void:
	pressure += amount
	_operation_history.append(valve)
	match valve:
		Valve.RED: red_uses += 1
		Valve.BLUE: blue_uses += 1
		Valve.YELLOW: yellow_uses += 1
	if pressure > MAX_SAFE_PRESSURE:
		_reset_overpressure()
		return
	if pressure == MAX_SAFE_PRESSURE:
		_set_status_with_hint("压力已到安全边缘，继续加压将触发泄压。")
	else:
		_set_status("液压状态已更新。")
	pressure_changed.emit(pressure)
	_evaluate_unlock()


func _evaluate_unlock() -> void:
	if is_unlocked or pressure != TARGET_PRESSURE or not flow_down:
		return
	if red_uses != 1 or blue_uses != 2 or yellow_uses != 3:
		_set_status_with_hint("压力正确，但配比不符：需要一注水、两注汽、三回流。")
		return
	is_unlocked = true
	_set_status_with_hint("导流指示灯转绿。液压卡榫解除，主闸门自动开启。")
	unlocked.emit()
	_open_main_gate()


func _open_main_gate() -> void:
	if is_open:
		return
	is_open = true
	var gate := get_node_or_null(gate_path)
	if gate != null and gate.has_method("open_gate"):
		gate.call("open_gate")
	_set_status("主闸门开启，通道已开放。")


func _reset_overpressure() -> void:
	_apply_steam_damage()
	pressure = 0
	red_uses = 0
	blue_uses = 0
	yellow_uses = 0
	flow_down = false
	is_unlocked = false
	_operation_history.clear()
	_set_status_with_hint("安全阀喷出高温蒸汽！系统已泄压并重置。")
	pressure_changed.emit(pressure)


func _apply_steam_damage() -> void:
	var current: Node = self
	while current != null:
		if current.has_method("apply_player_damage"):
			current.call("apply_player_damage", 1, &"sewer_hydraulic_steam")
			return
		current = current.get_parent()


func _set_status(message: String) -> void:
	_status = message
	status_changed.emit(message)
	_update_presentation()


func _set_status_with_hint(message: String) -> void:
	_status = message
	status_changed.emit(message)
	_show_status_hint(message)
	_update_presentation()


func _show_status_hint(message: String) -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.push_text(message, "sewer_hydraulic_status", 3.0)


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	if is_inside_tree() and get_tree() != null:
		return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	return null


func _update_presentation() -> void:
	if not is_inside_tree():
		return
	var direction := get_node_or_null("PipeArt/DirectionValve") as Sprite2D
	if direction != null:
		direction.texture = direction_down_texture if flow_down else direction_up_texture
	var pointer := get_node_or_null("PipeArt/CentralPressureGauge/GaugePointer") as Sprite2D
	if pointer != null:
		pointer.rotation = _gauge_angle_for_pressure(pressure) - pointer_art_angle
	var readout := get_node_or_null("PipeArt/CentralPressureGauge/PressureReadout") as Label
	if readout != null:
		readout.text = "%.1f 巴" % float(pressure)
	var indicator := get_node_or_null("PipeArt/CentralPressureGauge/FlowIndicator") as Label
	if indicator != null:
		indicator.text = "● 顺流：已解锁" if is_unlocked else "● 导流锁定"
		indicator.modulate = Color(0.25, 1.0, 0.38) if is_unlocked else Color(1.0, 0.25, 0.2)


func _gauge_angle_for_pressure(value: int) -> float:
	var gauge := get_node_or_null("PipeArt/CentralPressureGauge") as Node2D
	if gauge == null:
		return 0.0
	var clamped_value := clampi(value, 0, 10)
	var lower_value := (clamped_value / 2) * 2
	var upper_value := mini(lower_value + 2, 10)
	var lower_mark := gauge.get_node_or_null(str(lower_value)) as Marker2D
	var upper_mark := gauge.get_node_or_null(str(upper_value)) as Marker2D
	if lower_mark == null:
		return 0.0
	var lower_angle := lower_mark.position.angle()
	if upper_mark == null or lower_value == upper_value:
		return lower_angle
	var segment_progress := float(clamped_value - lower_value) / float(upper_value - lower_value)
	return lerp_angle(lower_angle, upper_mark.position.angle(), segment_progress)
