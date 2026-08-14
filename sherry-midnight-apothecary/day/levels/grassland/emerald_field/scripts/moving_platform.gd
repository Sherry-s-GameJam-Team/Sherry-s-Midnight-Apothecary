extends AnimatableBody2D

@export var motion := Vector2(420.0, 0.0)
@export var travel_time := 2.4
@export var phase := 0.0
var _origin := Vector2.ZERO
var _elapsed := 0.0

func _ready() -> void:
    _origin = global_position
    _elapsed = phase * travel_time * 2.0

func _physics_process(delta: float) -> void:
    _elapsed += delta
    var cycle: float = maxf(travel_time * 2.0, 0.01)
    var t: float = fmod(_elapsed, cycle) / cycle
    var ping_pong: float = 0.5 - 0.5 * cos(t * TAU)
    global_position = _origin + motion * ping_pong

func reset_hazard() -> void:
    _elapsed = phase * travel_time * 2.0
    global_position = _origin
