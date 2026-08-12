class_name ReservoirDisplay
extends Control

@onready var pollution_bar: ProgressBar = %PollutionBar
@onready var supply_bar: ProgressBar = %SupplyBar
@onready var pressure_bar: ProgressBar = %PressureBar
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var water_fill: ColorRect = %WaterFill
@onready var limits_label: Label = %LimitsLabel


func update_display(pollution: float, supply: float, pressure: float, stability: float, config: Dictionary) -> void:
	pollution_bar.value = pollution * 100.0
	supply_bar.value = supply * 100.0
	pressure_bar.value = pressure * 100.0
	stability_bar.value = stability * 100.0
	water_fill.color = Color("a92836").lerp(Color("3f9da1"), 1.0 - pollution)
	water_fill.scale.y = clampf(0.25 + supply * 0.75, 0.25, 1.0)
	water_fill.position.y = 86.0 * (1.0 - water_fill.scale.y)
	limits_label.text = "安全区\n污染 ≤ %d%%\n供水 ≥ %d%%\n压力 %d%%—%d%%" % [
		int(float(config["safe_pollution_threshold"]) * 100.0),
		int(float(config["minimum_clean_supply"]) * 100.0),
		int(float(config["minimum_pressure"]) * 100.0),
		int(float(config["maximum_pressure"]) * 100.0),
	]
