class_name PressurePlate
extends Area2D

## Reality Pressure Plate system for Luca (Upper Floor).
## Operates lower Dream mechanisms, gates, light cones, and dream grasp defenses.

signal plate_activated
signal plate_deactivated
signal plate_impulse_fired

enum PlateType {
	HOLD,           # Active while character or object is standing on it. Deactivates on exit.
	WEIGHT_LOCKED,  # Activated by heavy pushable crate/bed. Locks permanently once activated.
	IMPULSE         # One-shot stomp pulse. Triggers instant pulse, then enters cooldown.
}

@export var plate_type: PlateType = PlateType.HOLD
@export var prompt_text: String = ""
@export var target_nodes: Array[NodePath] = []
@export var target_method_on_activate: String = "open"
@export var target_method_on_deactivate: String = "close"
@export var impulse_cooldown: float = 2.5
@export var press_depth: float = 6.0

@export var plate_color_idle: Color = Color(0.4, 0.45, 0.55, 1.0)
@export var plate_color_active: Color = Color(0.3, 0.85, 1.0, 1.0)

var is_pressed: bool = false
var is_locked: bool = false
var _bodies_on_plate: Array[Node2D] = []
var _impulse_timer: float = 0.0

@onready var plate_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var indicator_light: Sprite2D = get_node_or_null("Indicator")


func _ready() -> void:
	collision_layer = 1 | 2
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visuals(false)


func _process(delta: float) -> void:
	if _impulse_timer > 0.0:
		_impulse_timer -= delta
		if _impulse_timer <= 0.0 and not is_pressed:
			_update_visuals(false)


func _on_body_entered(body: Node2D) -> void:
	if not _bodies_on_plate.has(body):
		_bodies_on_plate.append(body)

	match plate_type:
		PlateType.HOLD:
			if not is_pressed:
				_press_down()

		PlateType.WEIGHT_LOCKED:
			if is_locked:
				return
			# Check if body is pushable crate or heavy object
			if body.is_in_group("pushable_crate") or body.is_in_group("heavy_object") or _is_crate(body):
				is_locked = true
				_press_down()

		PlateType.IMPULSE:
			if _impulse_timer <= 0.0:
				_fire_impulse()


func _on_body_exited(body: Node2D) -> void:
	if _bodies_on_plate.has(body):
		_bodies_on_plate.erase(body)

	if plate_type == PlateType.HOLD:
		if _bodies_on_plate.is_empty() and is_pressed:
			_release_up()


func _press_down() -> void:
	is_pressed = true
	_update_visuals(true)
	plate_activated.emit()
	_notify_targets(target_method_on_activate)


func _release_up() -> void:
	if is_locked:
		return
	is_pressed = false
	_update_visuals(false)
	plate_deactivated.emit()
	_notify_targets(target_method_on_deactivate)


func _fire_impulse() -> void:
	_impulse_timer = impulse_cooldown
	_update_visuals(true)
	plate_impulse_fired.emit()
	_notify_targets(target_method_on_activate)

	# Quick bounce animation
	if plate_sprite != null:
		var original_y := plate_sprite.position.y
		var tw := create_tween()
		tw.tween_property(plate_sprite, "position:y", original_y + press_depth, 0.08)
		tw.tween_property(plate_sprite, "position:y", original_y, 0.2).set_delay(0.12)


func _notify_targets(method_name: String) -> void:
	if method_name.is_empty():
		return
	for path in target_nodes:
		var node := get_node_or_null(path)
		if node != null and node.has_method(method_name):
			node.call(method_name)


func _update_visuals(active: bool) -> void:
	if plate_sprite != null:
		var target_color := plate_color_active if active else plate_color_idle
		var tw := create_tween()
		tw.tween_property(plate_sprite, "modulate", target_color, 0.15)

	if indicator_light != null:
		indicator_light.modulate = plate_color_active if active else plate_color_idle


func _is_crate(body: Node2D) -> bool:
	return body != null and (body.name.contains("Crate") or body.name.contains("Bed") or body is PushableCrate)
