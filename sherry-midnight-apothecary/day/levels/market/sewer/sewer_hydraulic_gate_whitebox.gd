class_name SewerHydraulicGateWhitebox
extends Node2D

## Gate presentation. State textures are scene-assigned so the puzzle remains
## independent from individual art assets.
@export var open_distance := 250.0
@export var open_duration := 1.1
@export var closed_texture: Texture2D
@export var open_texture: Texture2D

var _opened := false

@onready var _sprite: Sprite2D = $GateSprite


func _ready() -> void:
	if _sprite != null and closed_texture != null:
		_sprite.texture = closed_texture


func open_gate() -> void:
	if _opened:
		return
	_opened = true
	if _sprite != null and open_texture != null:
		_sprite.texture = open_texture
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - open_distance, open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
