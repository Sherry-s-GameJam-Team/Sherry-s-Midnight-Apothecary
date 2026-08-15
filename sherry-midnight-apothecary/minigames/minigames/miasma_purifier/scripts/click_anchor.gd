extends Node2D
class_name MiasmaClickAnchor

@export var hit_radius: float = 52.0
@export var lifetime: float = 1.05
@export_range(0.0, 1.0, 0.01) var open_ratio: float = 0.28

var elapsed: float = 0.0
var sequence_number: int = 1
var resolved: bool = false

func _ready() -> void:
    z_index = 50
    queue_redraw()

func advance(delta: float) -> bool:
    if resolved:
        return false
    elapsed += delta
    queue_redraw()
    return elapsed >= lifetime

func can_hit() -> bool:
    return not resolved and progress() >= open_ratio and elapsed <= lifetime

func is_point_inside(world_point: Vector2) -> bool:
    return global_position.distance_to(world_point) <= hit_radius

func progress() -> float:
    return clampf(elapsed / maxf(lifetime, 0.001), 0.0, 1.0)

func resolve() -> void:
    resolved = true
    queue_free()

func _draw() -> void:
    var p := progress()
    var clickable := p >= open_ratio
    var approach_radius := lerpf(hit_radius * 2.25, hit_radius, p)
    var base_color := Color(0.80, 1.0, 0.82, 0.92) if clickable else Color(0.72, 0.92, 0.74, 0.55)
    var fill_color := Color(0.42, 0.92, 0.50, 0.24) if clickable else Color(0.38, 0.70, 0.42, 0.14)

    draw_circle(Vector2.ZERO, hit_radius, fill_color)
    draw_arc(Vector2.ZERO, hit_radius, 0.0, TAU, 64, base_color, 5.0, true)
    draw_arc(Vector2.ZERO, approach_radius, 0.0, TAU, 64, Color(0.95, 1.0, 0.90, 0.82), 4.0, true)
    draw_circle(Vector2.ZERO, 7.0, base_color)
