class_name HeatController
extends Node

signal temperature_updated(temperature: float, fire_power: float)
signal brew_finished(result: HeatResult)

enum HeatState { IDLE, BREWING, FINISHED, BURNED }

@export_group("Thermal Physics")
@export_range(0.0, 100.0, 0.1) var ambient_temperature := 20.0
@export_range(0.0, 100.0, 0.1) var initial_temperature := 20.0
@export_range(1.0, 150.0, 0.1) var maximum_temperature := 100.0
@export_range(0.0, 200.0, 0.1) var heat_gain := 95.0
@export_range(0.0, 5.0, 0.01) var cooling_rate := 0.55
@export_range(0.1, 20.0, 0.1) var thermal_mass := 5.0
@export_range(0.0, 5.0, 0.01) var fire_decay := 0.30

var temperature := 20.0
var fire_power := 0.0
var brew_elapsed := 0.0
var brew_duration := 0.0
var time_in_ideal_range := 0.0
var time_underheated := 0.0
var time_overheated := 0.0
var time_burned := 0.0
var total_deviation := 0.0
var total_temperature_change := 0.0
var previous_temperature := 20.0
var has_reached_ideal_range := false
var current_profile: HeatProfileData
var state := HeatState.IDLE
var finish_on_duration := true


func _ready() -> void:
	temperature = clampf(initial_temperature, ambient_temperature, maximum_temperature)
	previous_temperature = temperature
	temperature_updated.emit(temperature, fire_power)


func _process(delta: float) -> void:
	advance(delta)


func start_brew(profile: HeatProfileData, complete_on_duration := true) -> bool:
	if state == HeatState.BREWING or profile == null or not profile.is_valid():
		return false
	current_profile = profile
	brew_duration = profile.brew_duration
	brew_elapsed = 0.0
	time_in_ideal_range = 0.0
	time_underheated = 0.0
	time_overheated = 0.0
	time_burned = 0.0
	total_deviation = 0.0
	total_temperature_change = 0.0
	has_reached_ideal_range = false
	previous_temperature = temperature
	finish_on_duration = complete_on_duration
	state = HeatState.BREWING
	return true


func add_bellows_pump(effective_strength: float) -> void:
	if state != HeatState.BREWING:
		return
	fire_power = clampf(fire_power + maxf(effective_strength, 0.0), 0.0, 1.0)
	temperature_updated.emit(temperature, fire_power)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	fire_power = move_toward(fire_power, 0.0, fire_decay * delta)
	var heat_input := fire_power * heat_gain
	var cooling := cooling_rate * maxf(temperature - ambient_temperature, 0.0)
	temperature = clampf(
		temperature + (heat_input - cooling) / thermal_mass * delta,
		ambient_temperature,
		maximum_temperature,
	)
	if state == HeatState.BREWING:
		_record_temperature(delta)
		temperature_updated.emit(temperature, fire_power)
		if _is_burned() or (finish_on_duration and brew_elapsed >= brew_duration):
			_finish(_is_burned())
	else:
		temperature_updated.emit(temperature, fire_power)


func simulate(seconds: float, step := 0.1) -> void:
	var remaining := maxf(seconds, 0.0)
	while remaining > 0.0 and state == HeatState.BREWING:
		var delta := minf(step, remaining)
		advance(delta)
		remaining -= delta


func complete_brew() -> void:
	if state == HeatState.BREWING:
		_finish(_is_burned())


func _record_temperature(delta: float) -> void:
	brew_elapsed += delta
	var center := (current_profile.ideal_min + current_profile.ideal_max) * 0.5
	var is_in_ideal_range := temperature >= current_profile.ideal_min and temperature <= current_profile.ideal_max
	if is_in_ideal_range:
		time_in_ideal_range += delta
	elif temperature < current_profile.ideal_min:
		time_underheated += delta
	else:
		time_overheated += delta
	if temperature >= current_profile.burn_temperature:
		time_burned += delta
	total_deviation += absf(temperature - center) * delta
	# Reaching the working range from room temperature is required setup, not
	# unstable heat control. Volatility begins with the first ideal-range sample.
	if has_reached_ideal_range:
		total_temperature_change += absf(temperature - previous_temperature)
	elif is_in_ideal_range:
		has_reached_ideal_range = true
	previous_temperature = temperature


func _is_burned() -> bool:
	return (
		time_burned >= current_profile.allowed_burn_seconds
		or time_burned / maxf(brew_duration, 0.001) >= 0.20
	)


func _finish(burned: bool) -> void:
	var result := HeatResult.new()
	var duration := maxf(brew_duration, 0.001)
	result.range_ratio = clampf(time_in_ideal_range / duration, 0.0, 1.0)
	result.underheat_ratio = clampf(time_underheated / duration, 0.0, 1.0)
	result.overheat_ratio = clampf(time_overheated / duration, 0.0, 1.0)
	result.burn_ratio = clampf(time_burned / duration, 0.0, 1.0)
	result.average_deviation = total_deviation / duration
	var deviation_score := 1.0 - clampf(result.average_deviation / current_profile.deviation_limit, 0.0, 1.0)
	result.stability_score = (
		1.0 - clampf(total_temperature_change / current_profile.volatility_limit, 0.0, 1.0)
		if has_reached_ideal_range
		else 0.0
	)
	result.thermal_score = clampf(result.range_ratio * 0.55 + deviation_score * 0.30 + result.stability_score * 0.15, 0.0, 1.0)
	result.quality_multiplier = lerpf(0.65, 1.20, result.thermal_score)
	var mild_overheat_bonus := clampf(result.overheat_ratio, 0.0, 0.20) * 0.5
	result.potency_multiplier = clampf(0.70 + result.thermal_score * 0.45 + mild_overheat_bonus - result.burn_ratio * 0.60, 0.50, 1.25)
	result.duration_multiplier = clampf(0.65 + result.range_ratio * 0.40 + result.stability_score * 0.20 - result.overheat_ratio * 0.30 - result.burn_ratio * 0.50, 0.40, 1.30)
	result.is_burned = burned
	if result.thermal_score >= current_profile.secondary_effect_required_score:
		result.preserve_secondary_effect = true
		result.secondary_effect_multiplier = 1.0
	elif result.thermal_score >= 0.50:
		result.preserve_secondary_effect = true
		result.secondary_effect_multiplier = 0.5
	state = HeatState.BURNED if burned else HeatState.FINISHED
	brew_finished.emit(result)
