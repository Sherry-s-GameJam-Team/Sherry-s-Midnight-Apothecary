class_name ControlledMovingPlatform
extends ControlledBase

## 受控往复移动平台：激活时沿 target_offset 做往复运动，未激活时停在当前位置。

@export var target_offset := Vector2(100.0, 0.0)
@export_range(0.1, 60.0, 0.1) var travel_time := 2.0
@export_range(0.0, 10.0, 0.05) var pause_time := 0.5
@export_enum("Linear", "Smooth") var easing := 1
@export var auto_start := false

@onready var _visual: Polygon2D = $Visual
@onready var _body: AnimatableBody2D = $Body
@onready var _destination_marker: Marker2D = get_node_or_null("DestinationMarker")

var _origin := Vector2.ZERO
var _elapsed := 0.0
var _moving := false


func _ready() -> void:
	super()
	if _destination_marker != null:
		target_offset = _destination_marker.position
	_origin = global_position
	if auto_start:
		set_controlled_active(true)


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	
	var cycle := maxf(travel_time * 2.0 + pause_time * 2.0, 0.001)
	_elapsed += delta
	var t := fmod(_elapsed, cycle)
	var ping_pong := _compute_ping_pong(t)
	global_position = _origin + target_offset * ping_pong


func _compute_ping_pong(t: float) -> float:
	var forward_end := travel_time
	var pause_at_end := forward_end + pause_time
	var backward_end := pause_at_end + travel_time

	if t < forward_end:
		return _apply_ease(t / maxf(travel_time, 0.001))
	if t < pause_at_end:
		return 1.0
	if t < backward_end:
		var return_t := (t - pause_at_end) / maxf(travel_time, 0.001)
		return 1.0 - _apply_ease(return_t)
	return 0.0


func _apply_ease(t: float) -> float:
	match easing:
		0:
			return t
		_:
			return t * t * (3.0 - 2.0 * t)


func _on_state_changed(active: bool) -> void:
	_moving = active


func _update_visual(active: bool) -> void:
	if _visual == null:
		return
	_visual.color = active_color if active else inactive_color
