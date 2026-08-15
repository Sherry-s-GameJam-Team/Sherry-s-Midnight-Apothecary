class_name PlayerHealthHUD
extends Control

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel

var _player_data: PlayerData


func bind_player_data(player_data: PlayerData) -> void:
	if _player_data != null and _player_data.health_changed.is_connected(_on_health_changed):
		_player_data.health_changed.disconnect(_on_health_changed)
	_player_data = player_data
	if _player_data != null:
		_player_data.health_changed.connect(_on_health_changed)
		_on_health_changed(_player_data.health, _player_data.max_health)


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	health_bar.max_value = maxi(maximum_health, 1)
	health_bar.value = clampi(current_health, 0, maximum_health)
	health_label.text = "HP %d / %d" % [current_health, maximum_health]
