class_name HelionHitFeedback extends Node

@export var visual_root: Node2D
@export var hit_flash: CanvasItem
@export var core_glow: CanvasItem

var cooldown: float = 0.1
var _cooldown_timer: float = 0.0

var _visual_tween: Tween
var _flash_tween: Tween
var _glow_tween: Tween
var _camera_tween: Tween

var _original_glow_modulate: Color = Color.WHITE

func _ready() -> void:
	if core_glow:
		_original_glow_modulate = core_glow.modulate

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func play_hit(recoil_min: float = 8.0, recoil_max: float = 14.0, flash_duration: float = 0.08, return_time: float = 0.06) -> void:
	if _cooldown_timer > 0.0:
		return
	_cooldown_timer = cooldown

	_apply_feedback(recoil_min, recoil_max, flash_duration, return_time, 2.0)

func play_break_feedback() -> void:
	if _cooldown_timer > 0.0:
		return
	_cooldown_timer = cooldown
	
	_apply_feedback(20.0, 20.0, 0.15, 0.1, 5.0)

func _apply_feedback(recoil_min: float, recoil_max: float, flash_duration: float, return_time: float, camera_shake: float) -> void:
	if visual_root:
		if _visual_tween and _visual_tween.is_valid():
			_visual_tween.kill()
		
		var random_angle: float = randf() * TAU
		var random_dist: float = randf_range(recoil_min, recoil_max)
		var offset: Vector2 = Vector2(cos(random_angle), sin(random_angle)) * random_dist
		
		visual_root.position = offset
		
		_visual_tween = create_tween()
		_visual_tween.tween_property(visual_root, "position", Vector2.ZERO, return_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	if hit_flash:
		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		
		hit_flash.modulate.a = 1.0
		_flash_tween = create_tween()
		_flash_tween.tween_property(hit_flash, "modulate:a", 0.0, flash_duration).set_trans(Tween.TRANS_LINEAR)

	if core_glow:
		if _glow_tween and _glow_tween.is_valid():
			_glow_tween.kill()
			
		core_glow.modulate = Color.WHITE
		_glow_tween = create_tween()
		_glow_tween.tween_property(core_glow, "modulate", _original_glow_modulate, 0.1).set_trans(Tween.TRANS_LINEAR)

	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		if _camera_tween and _camera_tween.is_valid():
			_camera_tween.kill()
		
		var random_angle: float = randf() * TAU
		var offset: Vector2 = Vector2(cos(random_angle), sin(random_angle)) * camera_shake
		
		var orig_pos: Vector2 = camera.offset # Using offset for camera shake relative to its tracking position
		camera.offset = orig_pos + offset
		
		_camera_tween = create_tween()
		_camera_tween.tween_property(camera, "offset", orig_pos, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
