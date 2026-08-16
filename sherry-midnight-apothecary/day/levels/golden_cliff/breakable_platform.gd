extends Node2D

@export var warning_time: float = 0.85
@export var reset_time: float = 2.4
@export var fall_distance: float = 760.0
@export var enabled: bool = true

@onready var body: StaticBody2D = $Body
@onready var collision: CollisionShape2D = $Body/CollisionShape2D
@onready var sensor: Area2D = $Sensor
@onready var visual: Sprite2D = $Visual

var _busy := false
var _origin := Vector2.ZERO
var _visual_origin := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _origin = position
    _visual_origin = visual.position
    _rng.randomize()
    sensor.body_entered.connect(_on_body_entered)

func set_enabled(value: bool) -> void:
    enabled = value
    if not value:
        _restore_immediately()

func _on_body_entered(other: Node2D) -> void:
    if not enabled or _busy or other.name != "Player":
        return
    _collapse_sequence()

func _collapse_sequence() -> void:
    _busy = true
    var warning := create_tween()
    warning.set_loops(5)
    warning.tween_property(visual, "position:x", _visual_origin.x + 6.0, warning_time / 10.0)
    warning.tween_property(visual, "position:x", _visual_origin.x - 6.0, warning_time / 10.0)
    await warning.finished
    visual.position.x = _visual_origin.x
    collision.set_deferred("disabled", true)
    sensor.set_deferred("monitoring", false)
    _spawn_dust(global_position + Vector2(0, 120), 14)
    var fall := create_tween()
    fall.set_parallel(true)
    fall.tween_property(self, "position:y", _origin.y + fall_distance, 0.78).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fall.tween_property(self, "rotation", 0.12, 0.78)
    fall.tween_property(self, "modulate:a", 0.25, 0.78)
    await fall.finished
    await get_tree().create_timer(reset_time).timeout
    _restore_immediately()
    _busy = false

func _restore_immediately() -> void:
    position = _origin
    rotation = 0.0
    modulate = Color.WHITE
    visual.position = _visual_origin
    collision.set_deferred("disabled", false)
    sensor.set_deferred("monitoring", true)

func _spawn_dust(world_position: Vector2, count: int) -> void:
    for index in range(count):
        var mote := Polygon2D.new()
        var size := _rng.randf_range(3.0, 8.0)
        mote.polygon = PackedVector2Array([
            Vector2(-size, -size * 0.5), Vector2(size, -size * 0.5),
            Vector2(size * 0.6, size * 0.6), Vector2(-size * 0.7, size * 0.8)
        ])
        mote.color = Color(0.78, 0.58, 0.30, 0.7)
        mote.z_index = 20
        get_parent().add_child(mote)
        mote.global_position = world_position
        var target := world_position + Vector2(_rng.randf_range(-150.0, 150.0), _rng.randf_range(-70.0, 35.0))
        var tween := mote.create_tween()
        tween.set_parallel(true)
        tween.tween_property(mote, "global_position", target, 0.65)
        tween.tween_property(mote, "modulate:a", 0.0, 0.65)
        tween.tween_property(mote, "scale", Vector2(1.8, 1.8), 0.65)
        tween.finished.connect(mote.queue_free)
