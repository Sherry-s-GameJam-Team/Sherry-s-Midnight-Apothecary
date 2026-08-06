class_name PotionThrowTuning
extends Resource

@export_range(0.05, 1.0, 0.05) var aim_time_scale := 0.3
@export_range(0.05, 1.0, 0.05) var flight_time_scale := 0.35
@export var allow_air_aim := false
@export_range(50.0, 2000.0, 10.0) var minimum_throw_speed := 350.0
@export_range(50.0, 2500.0, 10.0) var maximum_throw_speed := 1050.0
@export_range(1.0, 200.0, 1.0) var minimum_valid_drag_distance := 28.0
@export_range(20.0, 600.0, 5.0) var maximum_drag_distance := 260.0
@export_range(0.0, 4000.0, 25.0) var projectile_gravity := 1250.0
@export_range(0.01, 0.2, 0.01) var trajectory_step := 0.04
@export_range(0.2, 8.0, 0.1) var trajectory_max_time := 3.0
@export_range(4, 200, 1) var trajectory_max_points := 80
@export_range(0.01, 1.0, 0.01) var dose_per_throw := 0.25
@export_range(0.2, 8.0, 0.1) var camera_follow_max_time := 1.8
@export_range(0.5, 3.0, 0.05) var camera_zoom_multiplier := 1.35
@export_range(0.05, 1.0, 0.05) var camera_transition_duration := 0.22
@export var aim_origin_left := Vector2(-105.0, -28.0)
@export var aim_origin_right := Vector2(105.0, -28.0)
@export_range(4.0, 40.0, 1.0) var projectile_radius := 12.0
@export_range(0.5, 20.0, 0.5) var projectile_max_lifetime := 6.0
@export_flags_2d_physics var projectile_collision_mask := 1
