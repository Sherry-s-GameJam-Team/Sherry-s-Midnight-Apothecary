class_name SwingingPendulum
extends Node2D

@export var is_stabilized: bool = false
@export var max_swing_angle_deg: float = 48.0
@export var swing_frequency: float = 1.3
@export var arm_length: float = 340.0
@export var enables_anomalies: bool = true

signal beat_triggered(is_anomaly: bool)

var _time: float = 0.0
var _is_anomaly_cycle: bool = false
var _anomaly_cooldown: float = 6.0
var _frozen_timer: float = 0.0
var _has_warned_current_sweep: bool = false

@onready var arm_line: Line2D = get_node_or_null("ArmLine")
@onready var bob_platform: AnimatableBody2D = get_node_or_null("BobPlatform")
@onready var telegraph_light: Node2D = get_node_or_null("TelegraphLight")


func _ready() -> void:
	if bob_platform != null:
		bob_platform.sync_to_physics = true


func set_stabilized(val: bool) -> void:
	is_stabilized = val
	if telegraph_light != null and telegraph_light.has_method("set_stable"):
		telegraph_light.call("set_stable", val)


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "blue" in potion_id or "ice" in potion_id or "cyan" in potion_id:
		_frozen_timer = 3.5
		if bob_platform != null:
			bob_platform.modulate = Color(0.5, 0.8, 1.4)
	elif "orange" in potion_id or "speed" in potion_id:
		_time += PI * 0.5


func _physics_process(delta: float) -> void:
	if _frozen_timer > 0.0:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0 and bob_platform != null:
			bob_platform.modulate = Color.WHITE
		return

	_time += delta * swing_frequency

	if enables_anomalies and not is_stabilized:
		_anomaly_cooldown -= delta
		if _anomaly_cooldown <= 0.0:
			_anomaly_cooldown = 7.5
			_is_anomaly_cycle = not _is_anomaly_cycle
			beat_triggered.emit(_is_anomaly_cycle)
			if telegraph_light != null and telegraph_light.has_method("flash_signal"):
				telegraph_light.call("flash_signal", _is_anomaly_cycle)

	var effective_time := _time
	if _is_anomaly_cycle and not is_stabilized:
		effective_time = _time * 0.5 + sin(_time * 2.0) * 0.3

	var current_angle_rad := deg_to_rad(max_swing_angle_deg) * sin(effective_time)

	var near_bottom := absf(sin(effective_time)) < 0.25
	if near_bottom and not _has_warned_current_sweep:
		_has_warned_current_sweep = true
		var audio: Node = get_tree().get_first_node_in_group("clocktower_audio")
		if audio != null and audio.has_method("play_bell_warning"):
			audio.call("play_bell_warning", _is_anomaly_cycle)
	elif not near_bottom:
		_has_warned_current_sweep = false

	rotation = current_angle_rad
	if bob_platform != null:
		bob_platform.position = Vector2(0, arm_length)
		bob_platform.rotation = -current_angle_rad
