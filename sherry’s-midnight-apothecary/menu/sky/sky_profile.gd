class_name MenuSkyProfile
extends Resource

@export var profile_id: StringName = &"day_01_default"
@export var display_name := "Day 1 · Default"
@export_range(1, 999, 1) var start_day := 1

@export_group("Sky")
@export var top_color := Color("69b4df")
@export var horizon_color := Color("b8dce9")
@export var bottom_color := Color("f3d5ad")
@export var ambient_tint := Color("fff0d3")
@export_range(0.0, 0.2, 0.001) var noise_strength := 0.0

@export_group("Clouds")
@export var cloud_texture: Texture2D
@export_range(0.0, 1.0, 0.01) var cloud_opacity := 0.22
@export_range(-40.0, 40.0, 0.1) var cloud_speed := 3.0
@export_range(-40.0, 40.0, 0.1) var secondary_cloud_speed := -1.5

@export_group("Moon And Stars")
@export var moon_visible := false
@export var moon_texture: Texture2D
@export var moon_position := Vector2(350.0, 175.0)
@export_range(0.0, 1.0, 0.01) var moon_opacity := 0.72
@export_range(0, 256, 1) var star_density := 0
@export_range(0.0, 1.0, 0.01) var star_opacity := 0.0

@export_group("Magic And Foreground")
@export_range(0, 256, 1) var magic_particle_amount := 8
@export var magic_particle_color := Color("d8c5ff")
@export var foreground_tint := Color("254357")
@export_range(0.0, 1.0, 0.01) var shadow_strength := 0.58
@export var optional_overlay_texture: Texture2D
@export var optional_shader_parameters: Dictionary = {}
@export_range(0.0, 2.0, 0.01) var music_modifier := 1.0
