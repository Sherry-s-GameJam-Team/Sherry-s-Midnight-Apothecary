class_name CalibrationNode
extends Area2D

signal fixed(node_id: int)

@export var node_id: int = 1
@export var node_name_cn: String = "校时节点Ⅰ：主发条限位器"
@export var description_cn: String = "修复发条限位器，稳定下层机械脉冲。"
@export var is_fixed: bool = false
@export var linked_mechanism: NodePath
@export var linked_mechanisms: Array[NodePath] = []

var _player_in_range := false

@onready var glow_sprite: Sprite2D = get_node_or_null("GlowSprite")
@onready var gear_sprite: Sprite2D = get_node_or_null("GearSprite")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not is_fixed and _player_in_range and event.is_action_pressed("interact"):
		repair_node()
		get_viewport().set_input_as_handled()


func repair_node() -> void:
	if is_fixed:
		return
	is_fixed = true
	_update_visuals()
	_play_repair_celebration()
	fixed.emit(node_id)

	# Trigger linked platforms / mechanisms
	var target_list: Array[NodePath] = []
	if not linked_mechanism.is_empty():
		target_list.append(linked_mechanism)
	target_list.append_array(linked_mechanisms)

	for p in target_list:
		var mech := get_node_or_null(p)
		if mech != null:
			if mech.has_method("set_stabilized"):
				mech.call("set_stabilized", true)
			elif mech.has_method("activate_platform"):
				mech.call("activate_platform")
			elif mech.has_method("toggle_lift"):
				mech.call("toggle_lift")
			elif mech.has_method("toggle_platform"):
				mech.call("toggle_platform")

	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_calibration_fixed"):
				audio.call("play_calibration_fixed")

			var top_hint := _find_top_hint()
			if top_hint != null and top_hint.has_method("show_interaction_hint"):
				top_hint.call("show_interaction_hint", _hint_id(), "已修复 " + node_name_cn + "！")
				tree.create_timer(3.0).timeout.connect(func() -> void:
					var hint := _find_top_hint()
					if hint != null and hint.has_method("hide_interaction_hint"):
						hint.call("hide_interaction_hint", _hint_id())
				)


func _play_repair_celebration() -> void:
	if glow_sprite != null:
		var tween := create_tween()
		if tween != null:
			glow_sprite.modulate = Color(2.0, 1.8, 0.8, 1.0)
			tween.tween_property(glow_sprite, "scale", glow_sprite.scale * 1.5, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(glow_sprite, "scale", glow_sprite.scale, 0.35)
			tween.tween_property(glow_sprite, "modulate", Color(1.0, 0.85, 0.2, 1.0), 0.3)

	if gear_sprite != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(gear_sprite, "rotation", gear_sprite.rotation + TAU * 2.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func receive_potion_hit(_hit: Dictionary) -> void:
	if not is_fixed:
		repair_node()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_range = true
		if not is_fixed:
			var top_hint := _find_top_hint()
			if top_hint != null and top_hint.has_method("show_interaction_hint"):
				top_hint.call("show_interaction_hint", _hint_id(), "按 E 修复 " + node_name_cn)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_range = false
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("hide_interaction_hint"):
			top_hint.call("hide_interaction_hint", _hint_id())


func _hint_id() -> String:
	return "calib_node_%d" % node_id


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


func _process(delta: float) -> void:
	if gear_sprite != null:
		var speed := 1.0 if is_fixed else 4.0
		gear_sprite.rotation += speed * delta
	if glow_sprite != null:
		var pulse := (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
		glow_sprite.modulate.a = 0.6 + 0.4 * pulse


func _update_visuals() -> void:
	if glow_sprite != null:
		glow_sprite.modulate = Color(1.0, 0.85, 0.2, 1.0) if is_fixed else Color(1.0, 0.35, 0.1, 1.0)
	if prompt_label != null:
		prompt_label.visible = not is_fixed
		prompt_label.text = "[E] 修复"
