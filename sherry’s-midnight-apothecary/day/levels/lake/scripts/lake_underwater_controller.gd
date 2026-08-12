class_name LakeUnderwaterController
extends Node

signal entered_underwater
signal exited_underwater

@export var water_y := 1600.0
@export var bottom_y := 4300.0
@export_range(0.1, 3.0, 0.1) var transition_duration := 1.2
@export_node_path("Camera2D") var camera_path: NodePath
@export_node_path("ColorRect") var post_effect_path: NodePath
@export_node_path("ColorRect") var distortion_path: NodePath
@export_node_path("ColorRect") var caustics_path: NodePath
@export_node_path("Node2D") var god_rays_path: NodePath
@export_node_path("Node2D") var particles_path: NodePath

var _underwater := false
var _effect_amount := 0.0:
	set(value):
		_effect_amount = clampf(value, 0.0, 1.0)
		_apply_effect_amount()
var _tween: Tween

@onready var camera := get_node_or_null(camera_path) as Camera2D
@onready var post_effect := get_node_or_null(post_effect_path) as ColorRect
@onready var distortion := get_node_or_null(distortion_path) as ColorRect
@onready var caustics := get_node_or_null(caustics_path) as ColorRect
@onready var god_rays := get_node_or_null(god_rays_path) as Node2D
@onready var particles := get_node_or_null(particles_path) as Node2D


func _ready() -> void:
	_apply_effect_amount()


func configure(surface_y: float, lake_bottom_y: float) -> void:
	water_y = surface_y
	bottom_y = lake_bottom_y


func _process(_delta: float) -> void:
	if camera == null:
		return
	var now_underwater := camera.global_position.y >= water_y
	if now_underwater != _underwater:
		_set_underwater(now_underwater)
	var depth := clampf((camera.global_position.y - water_y) / maxf(bottom_y - water_y, 1.0), 0.0, 1.0)
	_set_shader_parameter(post_effect, &"depth_factor", depth)
	_set_shader_parameter(distortion, &"depth_factor", depth)
	_set_shader_parameter(caustics, &"depth_factor", depth)
	_update_screen_effect_positions()


func force_refresh(immediate := false) -> void:
	if camera == null:
		return
	var active := camera.global_position.y >= water_y
	_underwater = active
	if immediate:
		_effect_amount = 1.0 if active else 0.0
	else:
		_set_underwater(active)


func _set_underwater(active: bool) -> void:
	_underwater = active
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_effect_amount", 1.0 if active else 0.0, transition_duration)
	if active:
		entered_underwater.emit()
	else:
		exited_underwater.emit()


func _apply_effect_amount() -> void:
	_set_shader_parameter(post_effect, &"effect_strength", _effect_amount)
	_set_shader_parameter(distortion, &"effect_strength", _effect_amount)
	_set_shader_parameter(caustics, &"effect_strength", _effect_amount)
	if god_rays != null:
		god_rays.modulate.a = _effect_amount
	if particles != null:
		for child in particles.get_children():
			if child is GPUParticles2D:
				(child as GPUParticles2D).emitting = _effect_amount > 0.02
				(child as GPUParticles2D).amount_ratio = _effect_amount


func _update_screen_effect_positions() -> void:
	if camera == null:
		return
	var viewport_size := camera.get_viewport_rect().size
	for rect in [post_effect, distortion, caustics]:
		if rect == null:
			continue
		rect.global_position = camera.global_position - viewport_size * 0.5
		rect.size = viewport_size


func _set_shader_parameter(item: CanvasItem, parameter: StringName, value: Variant) -> void:
	if item == null or not item.material is ShaderMaterial:
		return
	(item.material as ShaderMaterial).set_shader_parameter(parameter, value)
