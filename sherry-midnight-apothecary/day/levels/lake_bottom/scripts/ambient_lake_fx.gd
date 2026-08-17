extends Node2D

@export var mote_count := 42
@export var area_size := Vector2(9600, 850)
@export var drift_speed := Vector2(10.0, -3.0)
var motes: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 170817
    for i in mote_count:
        motes.append({
            "p": Vector2(rng.randf_range(0.0, area_size.x), rng.randf_range(60.0, area_size.y)),
            "r": rng.randf_range(1.0, 3.2),
            "s": rng.randf_range(0.5, 1.4),
            "a": rng.randf_range(0.15, 0.5)
        })
    queue_redraw()

func _process(delta: float) -> void:
    for m in motes:
        m.p += drift_speed * float(m.s) * delta
        if m.p.x > area_size.x:
            m.p.x = 0.0
        if m.p.y < 0.0:
            m.p.y = area_size.y
    queue_redraw()

func _draw() -> void:
    for m in motes:
        draw_circle(m.p, m.r, Color(0.55, 0.95, 1.0, m.a))
