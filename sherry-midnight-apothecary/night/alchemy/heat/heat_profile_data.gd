class_name HeatProfileData
extends Resource

@export var id: StringName
@export_range(0.0, 100.0, 0.1) var ideal_min := 45.0
@export_range(0.0, 100.0, 0.1) var ideal_max := 60.0
@export_range(0.0, 100.0, 0.1) var warning_min := 35.0
@export_range(0.0, 100.0, 0.1) var warning_max := 70.0
@export_range(0.0, 100.0, 0.1) var burn_temperature := 82.0
@export_range(1.0, 60.0, 0.1) var brew_duration := 15.0
@export_range(0.0, 10.0, 0.1) var allowed_burn_seconds := 2.0
@export_range(0.0, 1.0, 0.01) var secondary_effect_required_score := 0.70
@export_range(0.0, 1.0, 0.01) var failure_score_threshold := 0.20
@export_range(1.0, 100.0, 0.5) var deviation_limit := 24.0
@export_range(1.0, 300.0, 1.0) var volatility_limit := 90.0


func is_valid() -> bool:
	return (
		ideal_min < ideal_max
		and warning_min <= ideal_min
		and warning_max >= ideal_max
		and burn_temperature > ideal_max
		and brew_duration > 0.0
	)
