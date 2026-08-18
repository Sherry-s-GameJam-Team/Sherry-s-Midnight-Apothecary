class_name CalibrationNode
extends Area2D

signal fixed(node_id: int)

@export var node_id: int = 1
@export var node_name_cn: String = "校时节点Ⅰ：主发条限位器"
@export var description_cn: String = "修复发条限位器，稳定下层机械脉冲。"
@export var is_fixed: bool = false

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
	fixed.emit(node_id)

	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_calibration_fixed"):
				audio.call("play_calibration_fixed")

			var top_hint := get_node_or_null("/root/TopHintUI")
			if top_hint != null and top_hint.has_method("show_interaction_hint"):
				top_hint.call("show_interaction_hint", "calib_node", "已修复 " + node_name_cn + "！")
				tree.create_timer(3.0).timeout.connect(func() -> void:
					if top_hint != null and top_hint.has_method("hide_hint"):
						top_hint.call("hide_hint", "calib_node")
				)


func receive_potion_hit(hit: Dictionary) -> void:
	if not is_fixed:
		repair_node()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_range = true
		if not is_fixed:
			var top_hint := get_node_or_null("/root/TopHintUI")
			if top_hint != null and top_hint.has_method("show_interaction_hint"):
				top_hint.call("show_interaction_hint", "calib_node", "按 E 修复 " + node_name_cn)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_in_range = false
		var top_hint := get_node_or_null("/root/TopHintUI")
		if top_hint != null and top_hint.has_method("hide_hint"):
			top_hint.call("hide_hint", "calib_node")


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
