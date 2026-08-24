class_name ClocktowerElevator
extends AnimatableBody2D

## Tower Elevator (通往第6层塔顶的机械升降电梯)
## 第五层校时完成后解锁激活，载乘主角平稳升至第六层塔顶。

signal elevator_arrived(floor_index: int)

@export var start_position: Vector2 = Vector2(516, -100)
@export var target_position: Vector2 = Vector2(516, -2075)
@export var is_unlocked: bool = false
@export var is_moving: bool = false
@export var travel_duration: float = 5.0

var _current_floor: int = 5
var _player_on_elevator: bool = false

@onready var ride_area: Area2D = get_node_or_null("RideArea")
@onready var glow_sprite: Sprite2D = get_node_or_null("Glow")


func _ready() -> void:
	sync_to_physics = true
	position = start_position
	visible = is_unlocked

	if ride_area != null:
		ride_area.body_entered.connect(_on_ride_area_entered)
		ride_area.body_exited.connect(_on_ride_area_exited)

	if glow_sprite != null:
		glow_sprite.visible = is_unlocked


func unlock_and_activate() -> void:
	is_unlocked = true
	visible = true
	position = start_position
	if glow_sprite != null:
		glow_sprite.visible = true
		var tween := create_tween()
		if tween != null:
			tween.tween_property(glow_sprite, "modulate:a", 1.0, 0.6)

	if is_inside_tree() and get_tree() != null:
		var audio: Node = get_tree().get_first_node_in_group("clocktower_audio")
		if audio != null and audio.has_method("play_gear_clack"):
			audio.call("play_gear_clack")


func _unhandled_input(event: InputEvent) -> void:
	if not is_unlocked or is_moving:
		return
	if _player_on_elevator and event.is_action_pressed("interact"):
		if _current_floor == 5:
			move_to_floor(6)
		else:
			move_to_floor(5)
		get_viewport().set_input_as_handled()


func move_to_floor(target_floor: int) -> void:
	if is_moving or not is_unlocked:
		return
	is_moving = true

	var dest: Vector2 = target_position if target_floor == 6 else start_position
	var tween := create_tween()
	if tween != null:
		tween.tween_property(self, "position", dest, travel_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.finished.connect(func() -> void:
			is_moving = false
			_current_floor = target_floor
			elevator_arrived.emit(_current_floor)
			_update_hint()
		)

	if is_inside_tree() and get_tree() != null:
		var audio: Node = get_tree().get_first_node_in_group("clocktower_audio")
		if audio != null and audio.has_method("play_gear_clack"):
			audio.call("play_gear_clack")


func _on_ride_area_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_on_elevator = true
		_update_hint()


func _on_ride_area_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_on_elevator = false
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("hide_interaction_hint"):
			top_hint.call("hide_interaction_hint", "elevator_hint")


func _update_hint() -> void:
	if not _player_on_elevator or not is_unlocked or is_moving:
		return
	var target_name := "第 6 层（塔顶巅峰）" if _current_floor == 5 else "第 5 层（校时室）"
	var top_hint := _find_top_hint()
	if top_hint != null and top_hint.has_method("show_interaction_hint"):
		top_hint.call("show_interaction_hint", "elevator_hint", "按 E 启动升降机前往 " + target_name)


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null and top_hint.is_node_ready():
			return top_hint
		current = current.get_parent()
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		var top_hint := get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
		if top_hint != null and top_hint.is_node_ready():
			return top_hint
	return null
