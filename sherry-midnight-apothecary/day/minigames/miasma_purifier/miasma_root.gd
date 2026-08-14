class_name MiasmaPurifierRoot
extends Area2D

signal purified(root_id: String)

@export var root_id := "A"
@export var required_power := 1
@export var max_health := 100.0
@export var active := true

var health := 100.0
var permanently_cleared := false
var highlighted := false

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
	if permanently_cleared or not active or power != required_power:
		return false
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		permanently_cleared = true
		active = false
		fog.emitting = false
		purified.emit(root_id)
	_refresh_visual()
	return true


func _refresh_visual() -> void:
	var ratio := clampf(health / maxf(max_health, 0.001), 0.0, 1.0)
	core.modulate = Color(0.42, 0.9, 0.24, 0.96) if not permanently_cleared else Color(0.82, 1.0, 0.9, 0.6)
	core.scale = Vector2.ONE * (0.76 + ratio * 0.28)
	if highlighted and not permanently_cleared:
		core.modulate = Color(0.72, 1.0, 0.45, 1.0)
		core.scale *= 1.15
	label.visible = highlighted or permanently_cleared
