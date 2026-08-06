class_name PotionEffectTuning
extends Resource

@export_range(8.0, 500.0, 2.0) var effect_radius := 110.0
@export_range(0.0, 500.0, 1.0) var attack_damage := 24.0
@export_range(0.0, 2000.0, 10.0) var attack_knockback := 220.0
@export_range(0.0, 5.0, 0.05) var speed_bonus := 0.35
@export_range(0.0, 500.0, 1.0) var healing_amount := 28.0
@export_range(0.0, 500.0, 1.0) var shield_amount := 32.0
@export_range(0.0, 500.0, 1.0) var mana_amount := 25.0
@export_range(0.1, 30.0, 0.1) var base_status_duration := 4.0
@export_flags_2d_physics var effect_collision_mask := 0xffffffff

