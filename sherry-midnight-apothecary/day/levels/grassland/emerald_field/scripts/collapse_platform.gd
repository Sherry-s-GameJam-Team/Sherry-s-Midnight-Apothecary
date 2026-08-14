extends AnimatableBody2D

@export var warning_time := 0.48
@export var fall_distance := 620.0
@export var fall_time := 0.65
@export var reset_delay := 1.7

@onready var trigger: Area2D = $Trigger
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
var _origin := Vector2.ZERO
var _triggered := false
var _generation := 0

func _ready() -> void:
    add_to_group("resettable")
    _origin = global_position
    trigger.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if _triggered or not body.is_in_group("player"):
        return
    _triggered = true
    _generation += 1
    var generation := _generation
    var shake := create_tween()
    for i in range(5):
        shake.tween_property(sprite, "position:x", 5.0 if i % 2 == 0 else -5.0, warning_time / 5.0)
    shake.tween_property(sprite, "position:x", 0.0, 0.03)
    await get_tree().create_timer(warning_time).timeout
    if generation != _generation:
        return
    collider.set_deferred("disabled", true)
    trigger.monitoring = false
    var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    fall.tween_property(self, "global_position:y", _origin.y + fall_distance, fall_time)
    await fall.finished
    await get_tree().create_timer(reset_delay).timeout
    if generation == _generation:
        reset_hazard()

func reset_hazard() -> void:
    _generation += 1
    _triggered = false
    global_position = _origin
    sprite.position.x = 0.0
    sprite.modulate = Color.WHITE
    collider.set_deferred("disabled", false)
    trigger.set_deferred("monitoring", true)
