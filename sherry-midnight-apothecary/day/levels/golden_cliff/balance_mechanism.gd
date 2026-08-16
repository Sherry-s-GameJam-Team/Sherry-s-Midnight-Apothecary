extends StaticBody2D

signal stabilized(mechanism_id: StringName)

@export var mechanism_id: StringName = &"balance"
@export_range(1, 8, 1) var required_hits: int = 2
@export var unstable_wobble_pixels: float = 4.0
@export var unstable_wobble_speed: float = 5.0

@onready var visual: Node2D = $Visual

var _hit_count := 0
var _stabilized := false
var _base_visual_position := Vector2.ZERO
var _base_visual_scale := Vector2.ONE
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _base_visual_position = visual.position
    _base_visual_scale = visual.scale
    _rng.randomize()

func _process(_delta: float) -> void:
    if _stabilized:
        return
    var t := Time.get_ticks_msec() * 0.001
    visual.position = _base_visual_position + Vector2(
        sin(t * unstable_wobble_speed + float(get_instance_id() % 13)) * unstable_wobble_pixels,
        cos(t * unstable_wobble_speed * 0.73) * unstable_wobble_pixels * 0.35
    )

func receive_potion_hit(hit: Dictionary) -> void:
    if _stabilized:
        return
    _hit_count = min(_hit_count + 1, required_hits)
    var impact_point: Vector2 = hit.get("impact_point", global_position)
    _play_hit_feedback(impact_point)
    if _hit_count >= required_hits:
        _stabilize()

func apply_potion_effect(_effect_id: StringName, _context: Dictionary) -> void:
    # Direct bottle impacts are the intended calibration input. Splash effects are
    # intentionally ignored so one throw cannot resolve multiple mechanisms.
    pass

func _play_hit_feedback(impact_point: Vector2) -> void:
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(visual, "scale", _base_visual_scale * Vector2(1.04, 0.96), 0.08)
    tween.tween_property(visual, "scale", _base_visual_scale, 0.15)
    _spawn_ring(impact_point, Color(1.0, 0.78, 0.20, 0.9), 72.0)
    _spawn_fragments(impact_point, 6)

func _stabilize() -> void:
    _stabilized = true
    visual.position = _base_visual_position
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(visual, "scale", _base_visual_scale * 1.08, 0.18)
    tween.tween_property(visual, "scale", _base_visual_scale, 0.35)
    _spawn_ring(global_position, Color(1.0, 0.90, 0.45, 1.0), 170.0)
    stabilized.emit(mechanism_id)

func _spawn_ring(world_position: Vector2, color: Color, radius: float) -> void:
    var ring := Line2D.new()
    ring.width = 5.0
    ring.default_color = color
    ring.closed = true
    ring.z_index = 30
    var points := PackedVector2Array()
    for index in range(33):
        var angle := TAU * float(index) / 32.0
        points.append(Vector2(cos(angle), sin(angle)) * radius)
    ring.points = points
    get_parent().add_child(ring)
    ring.global_position = world_position
    ring.scale = Vector2(0.25, 0.25)
    var tween := ring.create_tween()
    tween.set_parallel(true)
    tween.tween_property(ring, "scale", Vector2(1.7, 1.7), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(ring, "modulate:a", 0.0, 0.42)
    tween.finished.connect(ring.queue_free)

func _spawn_fragments(world_position: Vector2, count: int) -> void:
    for index in range(count):
        var fragment := Polygon2D.new()
        fragment.polygon = PackedVector2Array([
            Vector2(-4, -2), Vector2(4, -3), Vector2(3, 3), Vector2(-3, 4)
        ])
        fragment.color = Color(0.92, 0.64, 0.22, 0.9)
        fragment.z_index = 31
        get_parent().add_child(fragment)
        fragment.global_position = world_position
        var angle := _rng.randf_range(-PI * 0.9, -PI * 0.1)
        var distance := _rng.randf_range(45.0, 120.0)
        var target := world_position + Vector2(cos(angle), sin(angle)) * distance + Vector2(0, 35)
        var tween := fragment.create_tween()
        tween.set_parallel(true)
        tween.tween_property(fragment, "global_position", target, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(fragment, "rotation", _rng.randf_range(-2.5, 2.5), 0.42)
        tween.tween_property(fragment, "modulate:a", 0.0, 0.42)
        tween.finished.connect(fragment.queue_free)
