class_name ClockHandsFloor
extends Node2D

## Floor 4: Clock Hands Floor (指针层)
## Giant clock face, Hour & Minute hands platforms, hand crank wheel,
## Roman numeral target doors (III secret room, XII tower top route), and rewind jerk hazard.

@export var is_stabilized: bool = false
@export var current_minute_hour: int = 1 # 1 to 12
@export var current_hour_hour: int = 12

signal hour_changed(new_hour: int)
signal secret_gate_opened
signal tower_top_path_opened

var _is_jerking: bool = false
var _jerk_cooldown: float = 14.0
var _frozen_timer: float = 0.0

@onready var minute_hand_node: AnimatableBody2D = get_node_or_null("ClockCenter/MinuteHand")
@onready var hour_hand_node: AnimatableBody2D = get_node_or_null("ClockCenter/HourHand")
@onready var crank_wheel_area: Area2D = get_node_or_null("HandCrankArea")
@onready var secret_gate_3: StaticBody2D = get_node_or_null("SecretGate3")
@onready var dial_label_3: Label = get_node_or_null("DialNumerals/Num3")
@onready var dial_label_12: Label = get_node_or_null("DialNumerals/Num12")


func _ready() -> void:
	if minute_hand_node != null:
		minute_hand_node.sync_to_physics = true
	if hour_hand_node != null:
		hour_hand_node.sync_to_physics = true
	if crank_wheel_area != null:
		crank_wheel_area.body_entered.connect(_on_crank_body_entered)
		crank_wheel_area.body_exited.connect(_on_crank_body_exited)
	_update_hands_rotation(false)


var _player_at_crank: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_at_crank and event.is_action_pressed("interact"):
		advance_minute_hand(1)
		get_viewport().set_input_as_handled()


func advance_minute_hand(hours: int = 1) -> void:
	current_minute_hour = ((current_minute_hour - 1 + hours) % 12) + 1
	_update_hands_rotation(true)

	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_clack"):
				audio.call("play_gear_clack")

	_check_targets()


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "blue" in potion_id or "ice" in potion_id or "cyan" in potion_id:
		_frozen_timer = 6.0
		if minute_hand_node != null:
			minute_hand_node.modulate = Color(0.5, 0.8, 1.4)
	elif "orange" in potion_id or "speed" in potion_id:
		advance_minute_hand(3)
	elif "red" in potion_id or "bomb" in potion_id:
		advance_minute_hand(1)


func _physics_process(delta: float) -> void:
	if _frozen_timer > 0.0:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0 and minute_hand_node != null:
			minute_hand_node.modulate = Color.WHITE
		return

	if is_stabilized:
		return

	_jerk_cooldown -= delta
	if _jerk_cooldown <= 1.2 and not _is_jerking:
		_telegraph_jerk()

	if _jerk_cooldown <= 0.0:
		_jerk_cooldown = 15.0
		_execute_jerk()


func _telegraph_jerk() -> void:
	_is_jerking = true
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_grind_warning"):
				audio.call("play_gear_grind_warning")

	if minute_hand_node != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(minute_hand_node, "position:x", minute_hand_node.position.x + 4.0, 0.08)
			tween.tween_property(minute_hand_node, "position:x", minute_hand_node.position.x - 4.0, 0.08)
			tween.set_loops(6)


func _execute_jerk() -> void:
	_is_jerking = false
	current_minute_hour = ((current_minute_hour - 2 + 12) % 12) + 1
	_update_hands_rotation(true)
	_check_targets()


func _update_hands_rotation(animate: bool) -> void:
	var minute_target_deg := float(current_minute_hour) * 30.0
	var hour_target_deg := float(current_hour_hour) * 30.0 + (float(current_minute_hour) / 12.0) * 30.0

	if animate and minute_hand_node != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(minute_hand_node, "rotation_degrees", minute_target_deg, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif minute_hand_node != null:
		minute_hand_node.rotation_degrees = minute_target_deg

	if hour_hand_node != null:
		hour_hand_node.rotation_degrees = hour_target_deg

	hour_changed.emit(current_minute_hour)


func _check_targets() -> void:
	if current_minute_hour == 3:
		if secret_gate_3 != null:
			var tween := create_tween()
			if tween != null:
				tween.tween_property(secret_gate_3, "position:y", -160.0, 0.4)
			secret_gate_opened.emit()
	else:
		if secret_gate_3 != null and secret_gate_3.position.y < 0.0:
			var tween := create_tween()
			if tween != null:
				tween.tween_property(secret_gate_3, "position:y", 0.0, 0.4)

	if current_minute_hour == 12:
		tower_top_path_opened.emit()


func _on_crank_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_at_crank = true
		var top_hint := get_node_or_null("/root/TopHintUI")
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", "clock_crank", "按 E 转动手轮（顺时针拨动指针）")


func _on_crank_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_at_crank = false
		var top_hint := get_node_or_null("/root/TopHintUI")
		if top_hint != null and top_hint.has_method("hide_hint"):
			top_hint.call("hide_hint", "clock_crank")
