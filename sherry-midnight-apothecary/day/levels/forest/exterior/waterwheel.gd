class_name ForestWaterwheel
extends Node2D

signal activated(wheel_id: StringName)

@export var wheel_id: StringName = &"wheel"
var active := false

@onready var receiver: ForestWaterReceiver = $WaterReceiver
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	receiver.water_received.connect(_on_water_received)
	if active:
		_apply_active_visual()
	else:
		sprite.play(&"idle")

func _on_water_received(_source: Node) -> void:
	activate_from_water()

func activate_from_water() -> void:
	if active:
		return
	active = true
	sprite.play(&"activate")
	await sprite.animation_finished
	if active:
		sprite.play(&"loop")
	activated.emit(wheel_id)

func restore_active() -> void:
	active = true
	receiver.supplied = true
	_apply_active_visual()

func _apply_active_visual() -> void:
	sprite.play(&"loop")
