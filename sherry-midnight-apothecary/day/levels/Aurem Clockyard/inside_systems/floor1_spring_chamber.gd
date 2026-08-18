class_name Floor1SpringChamber
extends Node2D

## Floor 1: Clockwork Chamber (发条与卷扬机工坊)
## Platforming Jumping & Puzzle Level:
## Sherry navigates hanging chain platforms, stepping stones, climbing ladder gantries,
## and moving winch lifts to bypass steam vents and reach Calibration Node 1.

@export var is_stabilized: bool = false
@export var cycle_duration: float = 4.0

var _cycle_timer: float = 0.0
var _is_frozen: bool = false
var _frozen_timer: float = 0.0

@onready var gauge_needle: Node2D = get_node_or_null("PressureGauge/Needle")
@onready var winch_lift_1: AnimatableBody2D = get_node_or_null("WinchLifts/WinchLift1")
@onready var winch_lift_2: AnimatableBody2D = get_node_or_null("WinchLifts/WinchLift2")
@onready var calib_node_1: Area2D = get_node_or_null("CalibrationNode1")


func _ready() -> void:
	pass


func set_stabilized(val: bool) -> void:
	is_stabilized = val
	if is_stabilized:
		if winch_lift_1 != null:
			winch_lift_1.modulate = Color(1.0, 0.95, 0.7)
		if winch_lift_2 != null:
			winch_lift_2.modulate = Color(1.0, 0.95, 0.7)


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "blue" in potion_id or "ice" in potion_id:
		_is_frozen = true
		_frozen_timer = 4.0
	elif "orange" in potion_id or "speed" in potion_id or "red" in potion_id:
		if winch_lift_1 != null and winch_lift_1.has_method("toggle_lift"):
			winch_lift_1.call("toggle_lift")
		if winch_lift_2 != null and winch_lift_2.has_method("toggle_lift"):
			winch_lift_2.call("toggle_lift")


func _physics_process(delta: float) -> void:
	if _is_frozen:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0:
			_is_frozen = false
		return

	_cycle_timer += delta
	var progress := fmod(_cycle_timer, cycle_duration) / cycle_duration

	if gauge_needle != null:
		var target_angle := lerpf(-PI * 0.7, PI * 0.7, progress if not is_stabilized else 0.5)
		gauge_needle.rotation = target_angle
