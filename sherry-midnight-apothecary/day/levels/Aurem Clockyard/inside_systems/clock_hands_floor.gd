class_name ClockHandsFloor
extends Node2D

## Floor 4: Clock Hands Floor (指针层)
## 巨型钟面双轴齿轮联动谜题：
## - 分针转动手轮：分针转动 3 次时，时针额外转动 1 次
## - 时针转动手轮：时针转动 1 次时，分针额外转动 9 次
## - 目标：分针指向 Ⅲ 开启密室，指向 Ⅻ 对齐通向塔顶之路

@export var is_stabilized: bool = false
@export var current_minute_hour: int = 1 # 1 to 12
@export var current_hour_hour: int = 12 # 1 to 12

signal hour_changed(new_hour: int)
signal minute_changed(new_minute: int)
signal secret_gate_opened
signal tower_top_path_opened

var _frozen_timer: float = 0.0
var _minute_step_counter: int = 0

@onready var minute_hand_node: AnimatableBody2D = get_node_or_null("ClockCenter/MinuteHand")
@onready var hour_hand_node: AnimatableBody2D = get_node_or_null("ClockCenter/HourHand")
@onready var minute_crank_area: Area2D = get_node_or_null("HandCrankArea")
@onready var hour_crank_area: Area2D = get_node_or_null("HourCrankArea")
@onready var secret_gate_3: StaticBody2D = get_node_or_null("SecretGate3")

var _player_at_minute_crank: bool = false
var _player_at_hour_crank: bool = false


func _ready() -> void:
	if minute_hand_node != null:
		minute_hand_node.sync_to_physics = true
	if hour_hand_node != null:
		hour_hand_node.sync_to_physics = true

	if minute_crank_area != null:
		minute_crank_area.body_entered.connect(_on_minute_crank_entered)
		minute_crank_area.body_exited.connect(_on_minute_crank_exited)

	if hour_crank_area != null:
		hour_crank_area.body_entered.connect(_on_hour_crank_entered)
		hour_crank_area.body_exited.connect(_on_hour_crank_exited)

	_update_hands_rotation(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if _player_at_minute_crank:
			turn_minute_hand(1)
			get_viewport().set_input_as_handled()
		elif _player_at_hour_crank:
			turn_hour_hand(1)
			get_viewport().set_input_as_handled()


## 拨动分针：每转动 3 次，时针额外转动 1 次
func turn_minute_hand(steps: int = 1) -> void:
	if _frozen_timer > 0.0:
		return

	_advance_minute_hand_raw(steps)

	_minute_step_counter += steps
	var extra_hours := _minute_step_counter / 3
	_minute_step_counter %= 3

	if extra_hours > 0:
		_advance_hour_hand_raw(extra_hours)

	_play_clack_audio()
	_update_hands_rotation(true)
	_check_targets()


## 拨动时针：每转动 1 次，分针额外转动 9 次
func turn_hour_hand(steps: int = 1) -> void:
	if _frozen_timer > 0.0:
		return

	_advance_hour_hand_raw(steps)
	_advance_minute_hand_raw(steps * 9)

	_play_clack_audio()
	_update_hands_rotation(true)
	_check_targets()


# 兼容既有接口
func advance_minute_hand(hours: int = 1) -> void:
	turn_minute_hand(hours)


func advance_hour_hand(hours: int = 1) -> void:
	turn_hour_hand(hours)


func _advance_minute_hand_raw(steps: int) -> void:
	current_minute_hour = ((current_minute_hour - 1 + steps) % 12) + 1
	minute_changed.emit(current_minute_hour)


func _advance_hour_hand_raw(steps: int) -> void:
	current_hour_hour = ((current_hour_hour - 1 + steps) % 12) + 1
	hour_changed.emit(current_hour_hour)


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "blue" in potion_id or "ice" in potion_id or "cyan" in potion_id:
		_frozen_timer = 6.0
		if minute_hand_node != null:
			minute_hand_node.modulate = Color(0.5, 0.8, 1.4)
		if hour_hand_node != null:
			hour_hand_node.modulate = Color(0.5, 0.8, 1.4)
	elif "orange" in potion_id or "speed" in potion_id:
		turn_minute_hand(3)
	elif "red" in potion_id or "bomb" in potion_id:
		turn_hour_hand(1)


func _physics_process(delta: float) -> void:
	if _frozen_timer > 0.0:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0:
			if minute_hand_node != null:
				minute_hand_node.modulate = Color.WHITE
			if hour_hand_node != null:
				hour_hand_node.modulate = Color.WHITE


func _update_hands_rotation(animate: bool) -> void:
	var minute_target_deg := float(current_minute_hour) * 30.0
	var hour_target_deg := float(current_hour_hour) * 30.0

	if animate:
		if minute_hand_node != null:
			var tween_m := create_tween()
			if tween_m != null:
				tween_m.tween_property(minute_hand_node, "rotation_degrees", minute_target_deg, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if hour_hand_node != null:
			var tween_h := create_tween()
			if tween_h != null:
				tween_h.tween_property(hour_hand_node, "rotation_degrees", hour_target_deg, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		if minute_hand_node != null:
			minute_hand_node.rotation_degrees = minute_target_deg
		if hour_hand_node != null:
			hour_hand_node.rotation_degrees = hour_target_deg


func _play_clack_audio() -> void:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_clack"):
				audio.call("play_gear_clack")


func _check_targets() -> void:
	if current_minute_hour == 3 or current_hour_hour == 3:
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


func _on_minute_crank_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_at_minute_crank = true
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", "minute_crank", "按 E 拨动分针")


func _on_minute_crank_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_at_minute_crank = false
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("hide_interaction_hint"):
			top_hint.call("hide_interaction_hint", "minute_crank")


func _on_hour_crank_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_at_hour_crank = true
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", "hour_crank", "按 E 拨动时针")


func _on_hour_crank_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_at_hour_crank = false
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("hide_interaction_hint"):
			top_hint.call("hide_interaction_hint", "hour_crank")


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	return null
