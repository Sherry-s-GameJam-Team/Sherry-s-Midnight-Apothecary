class_name PlayerHealthHUD
extends Control

@export var damage_delay: float = 0.4
@export var catchup_duration: float = 0.5

@onready var health_bar: ProgressBar = $BarSlot/HealthBar
@onready var delayed_health_bar: ProgressBar = $BarSlot/DelayedHealthBar
@onready var health_label: Label = $HealthLabel

var _player_data: PlayerData
var _last_health: int = -1
var _last_max_health: int = -1
var _delay_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_nodes()


func _ensure_nodes() -> void:
	if health_bar == null:
		health_bar = get_node_or_null("BarSlot/HealthBar") as ProgressBar
	if delayed_health_bar == null:
		delayed_health_bar = get_node_or_null("BarSlot/DelayedHealthBar") as ProgressBar
	if health_label == null:
		health_label = get_node_or_null("HealthLabel") as Label


func bind_player_data(player_data: PlayerData) -> void:
	_ensure_nodes()
	if _player_data != null and _player_data.health_changed.is_connected(_on_health_changed):
		_player_data.health_changed.disconnect(_on_health_changed)
	_player_data = player_data
	if _player_data != null:
		_player_data.health_changed.connect(_on_health_changed)
		_update_display(_player_data.health, _player_data.max_health, true)


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	_update_display(current_health, maximum_health, false)


func _update_display(current_health: int, maximum_health: int, immediate: bool = false) -> void:
	_ensure_nodes()
	var safe_max: int = maxi(maximum_health, 1)
	var clamped_health: int = clampi(current_health, 0, safe_max)

	if health_bar == null or delayed_health_bar == null:
		return

	health_bar.max_value = safe_max
	delayed_health_bar.max_value = safe_max

	if health_label != null:
		health_label.text = "HP %d / %d" % [clamped_health, safe_max]

	if immediate or _last_health < 0:
		if _delay_tween != null and _delay_tween.is_valid():
			_delay_tween.kill()
		health_bar.value = clamped_health
		delayed_health_bar.value = clamped_health
		_last_health = clamped_health
		_last_max_health = safe_max
		return

	if clamped_health < _last_health:
		# Taking damage: red bar drops immediately, yellow delayed bar follows smoothly
		health_bar.value = clamped_health

		if _delay_tween != null and _delay_tween.is_valid():
			_delay_tween.kill()

		if is_inside_tree():
			_delay_tween = create_tween()
			_delay_tween.tween_interval(damage_delay)
			_delay_tween.tween_property(delayed_health_bar, "value", float(clamped_health), catchup_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			delayed_health_bar.value = clamped_health
	else:
		# Healing: update both immediately without lag
		if _delay_tween != null and _delay_tween.is_valid():
			_delay_tween.kill()
		health_bar.value = clamped_health
		delayed_health_bar.value = clamped_health

	_last_health = clamped_health
	_last_max_health = safe_max

