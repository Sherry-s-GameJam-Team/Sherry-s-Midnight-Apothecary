class_name ClocktowerHangingPlatform
extends AnimatableBody2D

## 巨钟塔悬吊升降平台 (Hanging Platform)
## 位移目标位置直接写入自身脚本中：Vector2(-97, -416)

@export var target_position: Vector2 = Vector2(-97, -416)
@export var initial_position: Vector2 = Vector2(-97, -180)
@export var move_duration: float = 2.0
@export var is_activated: bool = false

var _progress: float = 0.0
var _is_frozen: bool = false
var _frozen_timer: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var chain_line: Line2D = get_node_or_null("ChainLine")


func _ready() -> void:
	sync_to_physics = true
	position = initial_position
	if is_activated:
		position = target_position
		_progress = 1.0


func activate_platform() -> void:
	if is_activated:
		return
	is_activated = true
	_play_activation_feedback()


func move_to_target_position() -> void:
	activate_platform()


func toggle_lift() -> void:
	toggle_platform()


func toggle_platform() -> void:
	is_activated = not is_activated
	_play_activation_feedback()


func _play_activation_feedback() -> void:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_clack"):
				audio.call("play_gear_clack")

	if sprite != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(sprite, "modulate", Color(1.3, 1.2, 0.7), 0.2)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "blue" in potion_id or "ice" in potion_id or "cyan" in potion_id:
		_is_frozen = true
		_frozen_timer = 4.0
		if sprite != null:
			sprite.modulate = Color(0.5, 0.8, 1.4)
	elif "orange" in potion_id or "speed" in potion_id or "red" in potion_id:
		activate_platform()


func _physics_process(delta: float) -> void:
	if _is_frozen:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0:
			_is_frozen = false
			if sprite != null:
				sprite.modulate = Color.WHITE
		return

	var target_p := 1.0 if is_activated else 0.0
	if not is_equal_approx(_progress, target_p):
		var speed := 1.0 / maxf(move_duration, 0.1)
		_progress = move_toward(_progress, target_p, speed * delta)
		var smooth_t := (1.0 - cos(_progress * PI)) * 0.5
		position = initial_position.lerp(target_position, smooth_t)

		if chain_line != null:
			chain_line.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -position.y)])
