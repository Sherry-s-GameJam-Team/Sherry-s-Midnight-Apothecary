extends Node

@export_range(1, 8, 1) var required_balance_count: int = 3

@onready var level_root: Node = get_parent()
@onready var mechanisms: Node = $"../Gameplay/BalanceMechanisms"
@onready var portal: Area2D = $"../Gameplay/ExitPortal"
@onready var portal_collision: CollisionShape2D = $"../Gameplay/ExitPortal/CollisionShape2D"
@onready var broken_visual: Sprite2D = $"../Gameplay/ExitPortal/PortalBroken"
@onready var repaired_visual: Sprite2D = $"../Gameplay/ExitPortal/PortalRepaired"
@onready var breakables: Node = $"../Gameplay/Breakables"

var _resolved: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    for mechanism in mechanisms.get_children():
        if mechanism.has_signal("stabilized"):
            mechanism.stabilized.connect(_on_mechanism_stabilized)
    if level_root.has_signal("environment_state_changed"):
        level_root.environment_state_changed.connect(_on_environment_state_changed)
    _set_portal_active(false)
    _apply_environment_state()

func _on_mechanism_stabilized(mechanism_id: StringName) -> void:
    if _resolved.has(mechanism_id):
        return
    _resolved[mechanism_id] = true
    if _resolved.size() >= required_balance_count:
        _resolve_disaster()

func _resolve_disaster() -> void:
    if level_root.has_method("set_corrupted"):
        level_root.set_corrupted(false)
    _set_portal_active(true)
    _play_portal_completion_effect()

func _set_portal_active(active: bool) -> void:
    portal.set_deferred("monitoring", active)
    portal.set_deferred("monitorable", active)
    portal_collision.set_deferred("disabled", not active)
    broken_visual.visible = not active
    repaired_visual.visible = active

func _on_environment_state_changed(_corrupted: bool) -> void:
    _apply_environment_state()

func _apply_environment_state() -> void:
    var corrupted := true
    if level_root.has_method("is_corrupted"):
        corrupted = level_root.is_corrupted()
    for platform in breakables.get_children():
        if platform.has_method("set_enabled"):
            platform.set_enabled(corrupted)
    if not corrupted:
        _set_portal_active(true)

func _play_portal_completion_effect() -> void:
    var center := portal.global_position
    for ring_index in range(3):
        var ring := Line2D.new()
        ring.width = 7.0 - float(ring_index)
        ring.default_color = Color(1.0, 0.86, 0.30, 0.85)
        ring.closed = true
        ring.z_index = 60
        var points := PackedVector2Array()
        for index in range(41):
            var angle := TAU * float(index) / 40.0
            points.append(Vector2(cos(angle), sin(angle)) * (90.0 + ring_index * 35.0))
        ring.points = points
        level_root.add_child(ring)
        ring.global_position = center
        ring.scale = Vector2(0.2, 0.2)
        var tween := ring.create_tween()
        tween.set_parallel(true)
        tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.7 + ring_index * 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tween.tween_property(ring, "modulate:a", 0.0, 0.7 + ring_index * 0.08)
        tween.finished.connect(ring.queue_free)
    for index in range(20):
        var spark := Polygon2D.new()
        var s := _rng.randf_range(2.5, 6.0)
        spark.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)])
        spark.color = Color(1.0, 0.78, 0.18, 0.95)
        spark.z_index = 61
        level_root.add_child(spark)
        spark.global_position = center
        var angle := _rng.randf_range(0.0, TAU)
        var radius := _rng.randf_range(110.0, 260.0)
        var target := center + Vector2(cos(angle), sin(angle)) * radius
        var tween := spark.create_tween()
        tween.set_parallel(true)
        tween.tween_property(spark, "global_position", target, 0.65)
        tween.tween_property(spark, "modulate:a", 0.0, 0.65)
        tween.finished.connect(spark.queue_free)
