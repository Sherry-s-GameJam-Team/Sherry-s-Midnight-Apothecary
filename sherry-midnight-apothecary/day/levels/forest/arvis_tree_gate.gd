class_name ForestArvisTreeGate
extends Node2D

signal opened

var is_open := false
var _opening := false

@onready var animation: AnimatedSprite2D = $Animation
@onready var static_open: Sprite2D = $OpenStatic
@onready var blocker: CollisionShape2D = $Blocker/CollisionShape2D
@onready var audio: AudioStreamPlayer2D = $OpenSFX

func _ready() -> void:
	animation.visible = not is_open
	static_open.visible = is_open
	blocker.disabled = is_open
	if not is_open:
		animation.play(&"closed")

func open_gate(skip_animation := false) -> void:
	if is_open or _opening:
		return
	_opening = true
	blocker.set_deferred("disabled", true)
	if skip_animation:
		_finish_open()
		return
	audio.play()
	animation.visible = true
	static_open.visible = false
	animation.play(&"open")
	await animation.animation_finished
	_finish_open()

func restore_open() -> void:
	is_open = true
	_opening = false
	animation.visible = false
	static_open.visible = true
	blocker.disabled = true

func _finish_open() -> void:
	is_open = true
	_opening = false
	animation.visible = false
	static_open.visible = true
	opened.emit()
