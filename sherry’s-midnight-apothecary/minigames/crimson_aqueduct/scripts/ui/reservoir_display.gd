class_name ReservoirDisplay
extends Control

@onready var pollution_bar: ProgressBar = %PollutionBar
@onready var supply_bar: ProgressBar = %SupplyBar
@onready var pressure_bar: ProgressBar = %PressureBar
@onready var stability_bar: ProgressBar = %StabilityBar
@onready var water_fill: ColorRect = %WaterFill


func update_display(pollution: float, supply: float, pressure: float, stability: float) -> void:
	pollution_bar.value = pollution * 100.0
	supply_bar.value = supply * 100.0
	pressure_bar.value = pressure * 100.0
	stability_bar.value = stability * 100.0
	water_fill.color = Color("9e2834").lerp(Color("3f9da1"), 1.0 - pollution)
	water_fill.scale.y = clampf(0.25 + supply * 0.75, 0.25, 1.0)
	water_fill.position.y = 98.0 * (1.0 - water_fill.scale.y)
