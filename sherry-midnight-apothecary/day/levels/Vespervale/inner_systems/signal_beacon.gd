class_name SignalBeacon
extends Area2D

## Signal Beacon / Terminal device.
## When activated (via E interaction, potion hit, or remote signal),
## it transmits the unlock signal to the EndlessCorridorManager.

signal beacon_activated

@export var is_activated: bool = false
@export var prompt_text: String = "按 E 激活回廊破界信号"
@export var corridor_manager_path: NodePath = NodePath("../../EndlessCorridorManager")
@export var active_color: Color = Color(0.3, 0.9, 1.0, 1.0)
@export var idle_color: Color = Color(0.7, 0.4, 0.8, 0.6)

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var light: Sprite2D = get_node_or_null("Light")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")


func _ready() -> void:
	collision_layer = 1 | 2
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if is_activated:
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		if _has_player_inside():
			activate_beacon()


func activate_beacon() -> void:
	if is_activated:
		return
	is_activated = true
	_update_visuals()
	beacon_activated.emit()

	var manager := get_node_or_null(corridor_manager_path) as EndlessCorridorManager
	if manager != null:
		manager.activate_signal()


func _on_body_entered(body: Node2D) -> void:
	if is_activated:
		return
	if body.name == "Player" or body.name == "Luca" or body is CharacterBody2D:
		_set_prompt_visible(true)


func _on_body_exited(body: Node2D) -> void:
	if not _has_player_inside():
		_set_prompt_visible(false)


func _has_player_inside() -> bool:
	for body in get_overlapping_bodies():
		if body.name == "Player" or body.name == "Luca" or body is CharacterBody2D:
			return true
	return false


func _set_prompt_visible(val: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = val and not is_activated


func _update_visuals() -> void:
	_set_prompt_visible(false)
	if light != null:
		var target_color := active_color if is_activated else idle_color
		var tw := create_tween()
		tw.tween_property(light, "modulate", target_color, 0.3)
