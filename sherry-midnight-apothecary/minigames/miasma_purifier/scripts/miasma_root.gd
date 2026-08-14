extends Area2D
class_name MiasmaRoot

signal purified(root_id: String)

@export var root_id: String = "A"
@export var required_power: int = 1
@export var max_health: float = 100.0
@export var active: bool = true
@export var regrow_rate: float = 8.0
@export var glow_color: Color = Color(0.55, 1.0, 0.35, 0.9)

var health: float
var highlighted := false
var permanently_cleared := false

@onready var core: Polygon2D = $Core
@onready var fog: GPUParticles2D = $Fog
@onready var label: Label = $Label

func _ready() -> void:
    health = max_health
    label.text = root_id
    _refresh_visual()

func set_highlighted(value: bool) -> void:
    highlighted = value
    _refresh_visual()

func apply_purification(amount: float, power: int) -> bool:
    if permanently_cleared or not active:
        return false
    if power != required_power:
        return false
    health = max(0.0, health - amount)
    _refresh_visual()
    if health <= 0.0:
        permanently_cleared = true
        active = false
        fog.emitting = false
        core.modulate = Color(0.86, 1.0, 0.92, 0.65)
        label.modulate = Color(0.8, 1.0, 0.85, 1.0)
        purified.emit(root_id)
    return true

func _process(delta: float) -> void:
    if active and not permanently_cleared and health < max_health:
        health = min(max_health, health + regrow_rate * delta)
        _refresh_visual()

func _refresh_visual() -> void:
    if permanently_cleared:
        return
    var ratio := clamp(health / max_health, 0.0, 1.0)
    core.modulate = Color(0.35 + 0.25 * ratio, 0.8, 0.18, 0.95)
    core.scale = Vector2.ONE * (0.75 + 0.3 * ratio)
    if highlighted:
        core.modulate = glow_color
        core.scale *= 1.15
        label.visible = true
    else:
        label.visible = false
