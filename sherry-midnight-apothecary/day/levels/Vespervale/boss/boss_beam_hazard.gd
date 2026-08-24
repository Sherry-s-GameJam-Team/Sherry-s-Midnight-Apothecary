class_name BossBeamHazard
extends Area2D

## Full-screen Telegraph Judgment Line / Dream Laser Hazard for Vesper Director Boss.
## Displays a warning laser line spanning across the entire screen, then erupts with high damage.

@export var telegraph_duration: float = 0.65
@export var beam_duration: float = 0.35
@export var damage: float = 35.0
@export var beam_thickness: float = 55.0

var _is_active: bool = false
var _has_damaged_player: bool = false

@onready var telegraph_line: Line2D = get_node_or_null("TelegraphLine")
@onready var beam_line: Line2D = get_node_or_null("BeamLine")
@onready var hit_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func setup_horizontal(y_pos: float, p_damage: float = 20.0, p_telegraph: float = 0.65) -> void:
	damage = p_damage
	telegraph_duration = p_telegraph
	global_position = Vector2(0, y_pos)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2 # Player & Luca
	monitoring = false
	body_entered.connect(_on_body_entered)

	if beam_line != null:
		beam_line.visible = false
	if hit_shape != null:
		hit_shape.disabled = true

	_start_telegraph()


func _start_telegraph() -> void:
	if telegraph_line != null:
		telegraph_line.visible = true
		telegraph_line.modulate.a = 0.2
		var tw := create_tween()
		tw.tween_property(telegraph_line, "modulate:a", 1.0, telegraph_duration * 0.5)
		tw.tween_property(telegraph_line, "modulate:a", 0.3, telegraph_duration * 0.25)
		tw.tween_property(telegraph_line, "modulate:a", 1.0, telegraph_duration * 0.25)
		tw.tween_callback(_erupt_beam)
	else:
		get_tree().create_timer(telegraph_duration).timeout.connect(_erupt_beam)


func _erupt_beam() -> void:
	_is_active = true
	monitoring = true
	if hit_shape != null:
		hit_shape.disabled = false

	if telegraph_line != null:
		telegraph_line.visible = false

	if beam_line != null:
		beam_line.visible = true
		beam_line.width = beam_thickness
		beam_line.modulate = Color(1.5, 0.6, 1.8, 1.0)
		var tw := create_tween()
		tw.tween_property(beam_line, "width", beam_thickness * 1.3, 0.08)
		tw.tween_property(beam_line, "width", 0.0, beam_duration - 0.08)
		tw.parallel().tween_property(beam_line, "modulate:a", 0.0, beam_duration - 0.08)
		tw.tween_callback(queue_free)

	# Check overlapping bodies immediately
	for body in get_overlapping_bodies():
		_check_hit(body)


func _on_body_entered(body: Node2D) -> void:
	if _is_active:
		_check_hit(body)


func _check_hit(body: Node2D) -> void:
	if _has_damaged_player or not _is_active:
		return
	if body.name == "Player" or (body.is_in_group("player") and body.name != "Luca"):
		_has_damaged_player = true
		if body.has_method("apply_damage"):
			body.call("apply_damage", damage, global_position)
		elif body.has_method("take_damage"):
			body.call("take_damage", damage)
