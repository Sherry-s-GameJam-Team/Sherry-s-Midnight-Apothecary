@tool
class_name MenuSkyController
extends Node

@export var preview_profile: MenuSkyProfile:
	set(value):
		preview_profile = value
		if Engine.is_editor_hint() and is_node_ready() and value != null:
			apply_profile(value)

@onready var sky_gradient: ColorRect = %SkyGradient
@onready var far_cloud: MenuCloudLayer = %FarCloud
@onready var near_cloud: MenuCloudLayer = %NearCloud
@onready var moon: Node2D = %Moon
@onready var stars: MenuStarField = %Stars
@onready var magic_particles: GPUParticles2D = %MagicParticles
@onready var foreground_nodes: Array[CanvasItem] = [%DistantForest, %ApothecaryHill, %TreeCanopyForeground]

var current_profile: MenuSkyProfile


func _ready() -> void:
	if preview_profile != null:
		apply_profile(preview_profile)


func apply_profile(profile: MenuSkyProfile) -> void:
	if profile == null or not is_node_ready():
		return
	current_profile = profile
	var material := sky_gradient.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("top_color", profile.top_color)
		material.set_shader_parameter("horizon_color", profile.horizon_color)
		material.set_shader_parameter("bottom_color", profile.bottom_color)
		material.set_shader_parameter("noise_strength", profile.noise_strength)
		for parameter_name: Variant in profile.optional_shader_parameters:
			material.set_shader_parameter(StringName(str(parameter_name)), profile.optional_shader_parameters[parameter_name])
	far_cloud.cloud_texture = profile.cloud_texture
	far_cloud.opacity = profile.cloud_opacity * 0.72
	far_cloud.drift_speed = profile.secondary_cloud_speed
	near_cloud.cloud_texture = profile.cloud_texture
	near_cloud.opacity = profile.cloud_opacity
	near_cloud.drift_speed = profile.cloud_speed
	moon.visible = profile.moon_visible
	moon.position = profile.moon_position
	moon.set("moon_texture", profile.moon_texture)
	moon.set("opacity", profile.moon_opacity)
	moon.set("shade_color", profile.top_color)
	stars.amount = profile.star_density
	stars.opacity = profile.star_opacity
	magic_particles.amount = profile.magic_particle_amount
	magic_particles.modulate = profile.magic_particle_color
	for foreground: CanvasItem in foreground_nodes:
		foreground.modulate = profile.foreground_tint


func set_reduced_motion(reduced: bool) -> void:
	far_cloud.set_process(not reduced)
	near_cloud.set_process(not reduced)
	magic_particles.emitting = not reduced
