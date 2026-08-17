class_name CrownVFXController
extends Node2D

@export var seraph_corrupted_path: NodePath
@export var seraph_normal_path: NodePath
@export var shockwave_rect_path: NodePath
@export var rain_far_path: NodePath
@export var rain_mid_path: NodePath
@export var rain_foreground_path: NodePath
@export var platform_splashes_path: NodePath
@export var gloomy_overlay_path: NodePath
@export var lightning_overlay_path: NodePath
@export var background_sprite_path: NodePath

@onready var seraph_corrupted: Sprite2D = get_node_or_null(seraph_corrupted_path)
@onready var seraph_normal: Sprite2D = get_node_or_null(seraph_normal_path)
@onready var shockwave_rect: ColorRect = get_node_or_null(shockwave_rect_path)
@onready var rain_far: CPUParticles2D = get_node_or_null(rain_far_path)
@onready var rain_mid: CPUParticles2D = get_node_or_null(rain_mid_path)
@onready var rain_foreground: CPUParticles2D = get_node_or_null(rain_foreground_path)
@onready var platform_splashes: CPUParticles2D = get_node_or_null(platform_splashes_path)
@onready var gloomy_overlay: ColorRect = get_node_or_null(gloomy_overlay_path)
@onready var lightning_overlay: ColorRect = get_node_or_null(lightning_overlay_path)
@onready var background_sprite: Sprite2D = get_node_or_null(background_sprite_path)

var _lightning_active := true
var _lightning_timer := 4.0


func _ready() -> void:
	if shockwave_rect != null:
		shockwave_rect.visible = false
	if lightning_overlay != null:
		lightning_overlay.modulate.a = 0.0
	if seraph_normal != null:
		seraph_normal.modulate.a = 0.0
		seraph_normal.visible = true
	set_weather_heavy(true)


func _process(delta: float) -> void:
	if _lightning_active:
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			_lightning_timer = randf_range(4.5, 8.5)
			trigger_lightning_flash()


func trigger_lightning_flash() -> void:
	if lightning_overlay == null:
		return
	var tween := create_tween()
	# Double-pulse flash
	tween.tween_property(lightning_overlay, "modulate:a", 0.55, 0.04)
	tween.tween_property(lightning_overlay, "modulate:a", 0.15, 0.07)
	tween.tween_property(lightning_overlay, "modulate:a", 0.75, 0.05)
	tween.tween_property(lightning_overlay, "modulate:a", 0.0, 0.4)


func set_weather_heavy(heavy: bool) -> void:
	_lightning_active = heavy
	if rain_far != null:
		rain_far.amount = 160 if heavy else 35
		rain_far.emitting = true
	if rain_mid != null:
		rain_mid.amount = 120 if heavy else 20
		rain_mid.emitting = true
	if rain_foreground != null:
		rain_foreground.amount = 80 if heavy else 10
		rain_foreground.emitting = true
	if platform_splashes != null:
		platform_splashes.amount = 50 if heavy else 10
		platform_splashes.emitting = true
	if gloomy_overlay != null:
		var target_a: float = 0.85 if heavy else 0.25
		var tween := create_tween()
		tween.tween_property(gloomy_overlay, "modulate:a", target_a, 1.5)


func play_purification_sequence(boss_position: Vector2) -> Signal:
	_lightning_active = false

	# 1. Fade out gloomy rain and storm overlays
	var weather_tween := create_tween().set_parallel(true)
	if gloomy_overlay != null:
		weather_tween.tween_property(gloomy_overlay, "modulate:a", 0.0, 3.5)
	if rain_far != null:
		weather_tween.tween_property(rain_far, "modulate:a", 0.0, 3.0)
	if rain_mid != null:
		weather_tween.tween_property(rain_mid, "modulate:a", 0.0, 2.5)
	if rain_foreground != null:
		weather_tween.tween_property(rain_foreground, "modulate:a", 0.0, 2.0)
	if platform_splashes != null:
		weather_tween.tween_property(platform_splashes, "modulate:a", 0.0, 2.0)

	# 2. Expand radial purification shockwave
	if shockwave_rect != null:
		shockwave_rect.visible = true
		if shockwave_rect.material is ShaderMaterial:
			var mat := shockwave_rect.material as ShaderMaterial
			var vp_size := get_viewport_rect().size
			var screen_pos := (boss_position / vp_size) if vp_size.x > 0 else Vector2(0.5, 0.5)
			mat.set_shader_parameter("center", screen_pos)
			mat.set_shader_parameter("radius", 0.0)
			var wave_tween := create_tween()
			wave_tween.tween_method(func(val: float):
				mat.set_shader_parameter("radius", val)
			, 0.0, 1.6, 2.4)

	# 3. Burst shedding dark particles around Seraph
	_spawn_purify_burst(boss_position)

	# 4. Cross-fade Corrupted to Normal Sprite
	var fade_tween := create_tween().set_parallel(true)
	if seraph_corrupted != null:
		fade_tween.tween_property(seraph_corrupted, "modulate:a", 0.0, 4.0)
	if seraph_normal != null:
		fade_tween.tween_property(seraph_normal, "modulate:a", 1.0, 4.0)

	# 5. Background golden glow tint
	if background_sprite != null:
		var bg_tween := create_tween()
		bg_tween.tween_property(background_sprite, "modulate", Color(1.15, 1.2, 1.05, 1.0), 4.0)

	return get_tree().create_timer(5.5).timeout


func _spawn_purify_burst(pos: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.position = pos
	burst.amount = 64
	burst.lifetime = 2.5
	burst.one_shot = true
	burst.explosiveness = 0.85
	burst.spread = 180.0
	burst.gravity = Vector2(0, -20)
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 220.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 6.0
	burst.color = Color(0.85, 1.0, 0.95, 0.9)
	add_child(burst)
	burst.emitting = true
