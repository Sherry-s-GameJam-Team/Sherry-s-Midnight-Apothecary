class_name LightTarget
extends Area2D

## Hanging lamp/target for Sherry to strike with thrown potions.
## When hit, illuminates and temporarily disables/stuns upper hazards for Luca.

signal target_illuminated(duration: float)

@export var disable_duration: float = 5.0
@export var is_one_shot: bool = false
@export var target_nodes: Array[NodePath] = []
@export var target_method_on_hit: String = "stun"

var is_lit: bool = false
var _light_timer: float = 0.0

@onready var lamp_sprite: Sprite2D = get_node_or_null("LampSprite")
@onready var light_glow: Sprite2D = get_node_or_null("LightGlow")


func _ready() -> void:
	add_to_group("potion_target")
	add_to_group("light_target")
	collision_layer = 1 | 2
	collision_mask = 1 | 2
	area_entered.connect(_on_area_entered)
	_update_visuals()


func _process(delta: float) -> void:
	if is_lit and not is_one_shot:
		_light_timer -= delta
		if _light_timer <= 0.0:
			is_lit = false
			_update_visuals()


func receive_potion_hit(_hit_data: Dictionary = {}) -> void:
	trigger_hit()


func trigger_hit() -> void:
	is_lit = true
	_light_timer = disable_duration
	target_illuminated.emit(disable_duration)
	_invoke_targets(target_method_on_hit, disable_duration)
	_update_visuals()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("potion_projectile") or area.name.to_lower().contains("potion"):
		trigger_hit()


func _invoke_targets(method_name: String, duration: float) -> void:
	for path in target_nodes:
		var target := get_node_or_null(path)
		if target != null:
			if target.has_method(method_name):
				target.call(method_name, duration)
			elif target.has_method("disable_temporary"):
				target.call("disable_temporary", duration)


func _update_visuals() -> void:
	if lamp_sprite != null:
		var target_color := Color(1.3, 1.2, 0.7, 1.0) if is_lit else Color(0.7, 0.65, 0.75, 0.8)
		lamp_sprite.modulate = target_color
	if light_glow != null:
		light_glow.visible = is_lit
		if is_lit:
			light_glow.modulate = Color(1.0, 0.9, 0.4, 0.8)
