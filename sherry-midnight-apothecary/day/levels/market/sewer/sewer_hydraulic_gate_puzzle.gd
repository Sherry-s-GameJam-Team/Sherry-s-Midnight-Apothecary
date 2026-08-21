class_name SewerHydraulicGatePuzzle
extends Node2D

## Sewer-only hydraulic lock.  The puzzle deliberately keeps its state local to
## the level: it has no persistent world-state or scene-flow dependency.

signal pressure_changed(pressure: int)
signal status_changed(message: String)
signal unlocked

enum Valve { RED, BLUE, YELLOW, GREEN, MAIN_WHEEL, RESET }

const TARGET_PRESSURE := 6
const MAX_SAFE_PRESSURE := 8
const REQUIRED_SEQUENCE: Array[int] = [Valve.RED, Valve.BLUE, Valve.YELLOW, Valve.YELLOW, Valve.BLUE, Valve.YELLOW]

@export var player_path: NodePath
@export var interact_action: StringName = &"interact"
@export var interaction_radius := 115.0
@export var gate_path: NodePath

var pressure := 0
var red_uses := 0
var blue_uses := 0
var yellow_uses := 0
var flow_down := false
var is_unlocked := false
var is_open := false
var _operation_history: Array[int] = []
var _player: CharacterBody2D
var _status := "主闸锁死：校准至 6.0 巴"

const _VALVE_POSITIONS := {
	Valve.RED: Vector2(2350, 425),
	Valve.BLUE: Vector2(2700, 425),
	Valve.YELLOW: Vector2(3050, 425),
	Valve.GREEN: Vector2(2525, 520),
	Valve.MAIN_WHEEL: Vector2(3500, 455),
	Valve.RESET: Vector2(3225, 565),
}


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_refresh_visual()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(interact_action) and _player != null:
		var valve := _nearest_valve(_player.global_position)
		if valve != -1:
			use_valve(valve)
			get_viewport().set_input_as_handled()


func use_valve(valve: Valve) -> void:
	match valve:
		Valve.RED:
			_use_pressure_valve(Valve.RED, 4)
		Valve.BLUE:
			if red_uses == 0:
				_set_status("管道剧烈敲击：必须先开启红色主供水阀。")
				return
			_use_pressure_valve(Valve.BLUE, 3)
		Valve.YELLOW:
			if blue_uses == 0:
				_set_status("管路结霜卡死：必须先以蒸汽升温。")
				return
			_use_pressure_valve(Valve.YELLOW, -1)
		Valve.GREEN:
			flow_down = not flow_down
			_set_status("换向阀：%s" % ("顺流（下）" if flow_down else "逆流（上）"))
			_evaluate_unlock()
		Valve.MAIN_WHEEL:
			_try_open_main_gate()
		Valve.RESET:
			reset_puzzle()
	_refresh_visual()


func _use_pressure_valve(valve: Valve, amount: int) -> void:
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
		_set_status("8.0 巴：警报与管道震动，切勿再加压。")
	else:
		_set_status("当前压力：%.1f 巴" % float(pressure))
	pressure_changed.emit(pressure)
	_evaluate_unlock()


func _evaluate_unlock() -> void:
	if is_unlocked or pressure != TARGET_PRESSURE or not flow_down:
		return
	if _operation_history != REQUIRED_SEQUENCE:
		_set_status("压力正确，但配比不符：需要一注水、两注汽、三回流。")
		return
	is_unlocked = true
	_set_status("导流指示灯转绿。液压卡榫解除：转动中央主手轮。")
	unlocked.emit()


func _try_open_main_gate() -> void:
	if not is_unlocked:
		_set_status("主手轮锁死：需 6.0 巴、顺流（下）与正确配比。")
		return
	if is_open:
		return
	is_open = true
	var gate := get_node_or_null(gate_path)
	if gate != null and gate.has_method("open_gate"):
		gate.call("open_gate")
	_set_status("主闸门开启，通道已开放。")


func _reset_overpressure() -> void:
	_apply_steam_damage()
	_reset_state("安全阀喷出高温蒸汽！系统泄压并重置为 0.0 巴。")


func reset_puzzle() -> void:
	if is_open:
		_set_status("主闸已开启，无需重置。")
		return
	_reset_state("已手动重置液压系统：0.0 巴。")


func _reset_state(message: String) -> void:
	pressure = 0
	red_uses = 0
	blue_uses = 0
	yellow_uses = 0
	flow_down = false
	is_unlocked = false
	_operation_history.clear()
	_set_status(message)
	pressure_changed.emit(pressure)
	_refresh_visual()


func _apply_steam_damage() -> void:
	var current: Node = self
	while current != null:
		if current.has_method("apply_player_damage"):
			current.call("apply_player_damage", 1, &"sewer_hydraulic_steam")
			return
		current = current.get_parent()


func _nearest_valve(player_position: Vector2) -> int:
	var nearest := -1
	var nearest_distance := interaction_radius
	for valve: int in _VALVE_POSITIONS:
		var distance := player_position.distance_to(_VALVE_POSITIONS[valve])
		if distance <= nearest_distance:
			nearest = valve
			nearest_distance = distance
	return nearest


func _set_status(message: String) -> void:
	_status = message
	status_changed.emit(message)


func _refresh_visual() -> void:
	if is_inside_tree():
		queue_redraw()


func _draw() -> void:
	# Whitebox pump modules, modeled after the reference's three valve towers,
	# lower directional valve, central gauge, and large lifting gate.
	for valve: int in [Valve.RED, Valve.BLUE, Valve.YELLOW]:
		_draw_valve_module(_VALVE_POSITIONS[valve], _valve_color(valve), _valve_name(valve))
	_draw_direction_module(_VALVE_POSITIONS[Valve.GREEN])
	_draw_gauge(_VALVE_POSITIONS[Valve.MAIN_WHEEL])
	_draw_reset_button(_VALVE_POSITIONS[Valve.RESET])
	draw_string(ThemeDB.fallback_font, Vector2(2240, 270), "液压主闸门泵房  ·  靠近装置按 [E] 操作", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(2240, 300), "锈蚀守则：先供水，再蒸汽，后回流。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.82, 0.72, 0.55))
	draw_string(ThemeDB.fallback_font, Vector2(2240, 322), "检修涂鸦：顺流（绿阀向下）才能冲开锁舌。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 0.9, 0.62))
	draw_string(ThemeDB.fallback_font, Vector2(2240, 344), "积水刻痕：一注水、两注汽、三回流。", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.75, 0.82, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(2240, 710), _status, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.9, 0.78))


func _draw_valve_module(position: Vector2, color: Color, title: String) -> void:
	# Pipe housing and colored handwheel are provided by scene art sprites.
	draw_arc(position, 67, 0.0, TAU, 28, color, 3)
	draw_string(ThemeDB.fallback_font, position + Vector2(-96, -112), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)


func _draw_direction_module(position: Vector2) -> void:
	var green := Color(0.25, 0.9, 0.38) if flow_down else Color(0.18, 0.35, 0.2)
	draw_rect(Rect2(position - Vector2(100, 70), Vector2(200, 140)), Color(0.1, 0.13, 0.12), true)
	draw_rect(Rect2(position - Vector2(100, 70), Vector2(200, 140)), green, false, 5)
	draw_line(position + Vector2(0, -38), position + Vector2(0, 38), green, 12)
	draw_colored_polygon(PackedVector2Array([position + Vector2(-23, 18), position + Vector2(23, 18), position + Vector2(0, 48)] if flow_down else [position + Vector2(-23, -18), position + Vector2(23, -18), position + Vector2(0, -48)]), green)
	draw_string(ThemeDB.fallback_font, position + Vector2(-78, -45), "绿阀：%s" % ("下 / 顺流" if flow_down else "上 / 逆流"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_gauge(position: Vector2) -> void:
	# Gauge housing is CENTRAL PRESSURE GAUGE& INDICATOR MODULE.png.
	var center := position + Vector2(0, -12)
	var needle_angle: float = lerpf(2.45, 0.65, float(pressure) / 9.0)
	draw_line(center, center + Vector2(76, 0).rotated(needle_angle), Color(0.78, 0.1, 0.08), 4)
	draw_circle(center, 7, Color(0.12, 0.12, 0.12))
	draw_string(ThemeDB.fallback_font, position + Vector2(-48, 124), "%.1f 巴" % float(pressure), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	var indicator: Color = Color(0.2, 0.9, 0.3) if is_unlocked else Color(0.9, 0.12, 0.1)
	draw_circle(position + Vector2(122, 105), 14, indicator)
	draw_string(ThemeDB.fallback_font, position + Vector2(-112, -142), "中央压力表 / 主手轮", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func _draw_reset_button(position: Vector2) -> void:
	draw_rect(Rect2(position - Vector2(90, 30), Vector2(180, 60)), Color(0.18, 0.18, 0.2), true)
	draw_rect(Rect2(position - Vector2(90, 30), Vector2(180, 60)), Color(0.8, 0.82, 0.86), false, 3)
	draw_string(ThemeDB.fallback_font, position + Vector2(-62, 7), "[E] 重置系统", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _valve_color(valve: Valve) -> Color:
	match valve:
		Valve.RED: return Color(0.9, 0.18, 0.14)
		Valve.BLUE: return Color(0.18, 0.48, 0.95)
		_: return Color(0.95, 0.75, 0.12)


func _valve_name(valve: Valve) -> String:
	match valve:
		Valve.RED: return "红阀：注水 +4 巴"
		Valve.BLUE: return "蓝阀：蒸汽 +3 巴"
		_: return "黄阀：回流 -1 巴"
