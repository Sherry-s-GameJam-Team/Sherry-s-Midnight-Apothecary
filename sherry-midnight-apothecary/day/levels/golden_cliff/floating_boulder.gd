extends AnimatableBody2D

@export var bob_amplitude: float = 28.0
@export var bob_speed: float = 1.1
@export var horizontal_amplitude: float = 18.0
@export var horizontal_speed: float = 0.55
@export var phase: float = 0.0

var _origin := Vector2.ZERO

func _ready() -> void:
    _origin = position

func _physics_process(_delta: float) -> void:
    var t := Time.get_ticks_msec() * 0.001
    position = _origin + Vector2(
        sin(t * horizontal_speed + phase) * horizontal_amplitude,
        sin(t * bob_speed + phase) * bob_amplitude
    )
