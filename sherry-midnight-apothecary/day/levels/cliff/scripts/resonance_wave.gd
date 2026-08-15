class_name CliffResonanceWave
extends Area2D

@export var speed := 920.0
@export var max_distance := 980.0
@export var direction := Vector2.RIGHT
@export var knockback_force := 280.0

var _origin := Vector2.ZERO
var _consumed := false
@onready var visual: ColorRect = $Visual


func _ready() -> void:
	add_to_group("cliff_resonance_wave")
	_origin = global_position
	var wave_material := visual.material.duplicate() as ShaderMaterial
	visual.material = wave_material
	wave_material.set_shader_parameter("travel_direction", direction.x)
	visual.scale.x = 1.0 if direction.x >= 0.0 else -1.0
	modulate.a = 0.0
	var appear := create_tween()
	appear.tween_property(self, "modulate:a", 1.0, 0.08)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	if global_position.distance_to(_origin) >= max_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _consumed or not body.is_in_group("player"):
		return
	_consumed = true
	var controller := get_tree().get_first_node_in_group("cliff_hazard_controller") as CliffHazardController
	if controller != null:
		controller.hit_player(body, &"resonance_wave", direction.normalized(), knockback_force)
	queue_free()
