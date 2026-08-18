class_name TowerTopSynchronizer
extends Node2D

## Tower Top: Grand Synchronization Device (塔顶校时台)
## Features 3 concentric rings (Outer: Spring, Middle: Gear, Inner: Pendulum).
## When all three markers align at the top 12 o'clock notch, the grand restoration triggers!

signal synchronization_completed

@export var is_synchronized: bool = false

var _outer_angle: float = 80.0
var _middle_angle: float = 190.0
var _inner_angle: float = 290.0

var _outer_locked: bool = false
var _middle_locked: bool = false
var _inner_locked: bool = false

var _outer_speed: float = 40.0
var _middle_speed: float = 65.0
var _inner_speed: float = 95.0

@onready var dial_base: Sprite2D = get_node_or_null("DialBase")
@onready var outer_ring: Node2D = get_node_or_null("DialBase/OuterRing")
@onready var middle_ring: Node2D = get_node_or_null("DialBase/MiddleRing")
@onready var inner_ring: Node2D = get_node_or_null("DialBase/InnerRing")

@onready var outer_lock_area: Area2D = get_node_or_null("Consoles/OuterLockConsole")
@onready var middle_lock_area: Area2D = get_node_or_null("Consoles/MiddleLockConsole")
@onready var inner_lock_area: Area2D = get_node_or_null("Consoles/InnerLockConsole")

@onready var exit_portal: Node2D = get_node_or_null("ExitPortal")
@onready var celebration_glow: Sprite2D = get_node_or_null("CelebrationGlow")

var _active_console_id: String = ""


func _ready() -> void:
	if outer_lock_area != null:
		outer_lock_area.body_entered.connect(func(b: Node2D) -> void: _on_console_entered(b, "outer"))
		outer_lock_area.body_exited.connect(func(b: Node2D) -> void: _on_console_exited(b, "outer"))
	if middle_lock_area != null:
		middle_lock_area.body_entered.connect(func(b: Node2D) -> void: _on_console_entered(b, "middle"))
		middle_lock_area.body_exited.connect(func(b: Node2D) -> void: _on_console_exited(b, "middle"))
	if inner_lock_area != null:
		inner_lock_area.body_entered.connect(func(b: Node2D) -> void: _on_console_entered(b, "inner"))
		inner_lock_area.body_exited.connect(func(b: Node2D) -> void: _on_console_exited(b, "inner"))

	if exit_portal != null:
		exit_portal.visible = false
	if celebration_glow != null:
		celebration_glow.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_synchronized:
		return
	if _active_console_id.length() > 0 and event.is_action_pressed("interact"):
		toggle_ring_lock(_active_console_id)
		get_viewport().set_input_as_handled()


func toggle_ring_lock(ring_id: String) -> void:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_clack"):
				audio.call("play_gear_clack")

	match ring_id:
		"outer":
			_outer_locked = not _outer_locked
		"middle":
			_middle_locked = not _middle_locked
		"inner":
			_inner_locked = not _inner_locked

	_check_alignment()


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "blue" in potion_id or "ice" in potion_id:
		_outer_angle = 0.0
		_middle_angle = 0.0
		_inner_angle = 0.0
		_outer_locked = true
		_middle_locked = true
		_inner_locked = true
		_check_alignment()
	elif "orange" in potion_id:
		toggle_ring_lock("outer")
	elif "red" in potion_id:
		toggle_ring_lock("middle")


func _physics_process(delta: float) -> void:
	if is_synchronized:
		return

	if not _outer_locked:
		_outer_angle = fmod(_outer_angle + _outer_speed * delta, 360.0)
	if not _middle_locked:
		_middle_angle = fmod(_middle_angle + _middle_speed * delta, 360.0)
	if not _inner_locked:
		_inner_angle = fmod(_inner_angle + _inner_speed * delta, 360.0)

	if outer_ring != null:
		outer_ring.rotation_degrees = _outer_angle
	if middle_ring != null:
		middle_ring.rotation_degrees = _middle_angle
	if inner_ring != null:
		inner_ring.rotation_degrees = _inner_angle


func _check_alignment() -> void:
	if is_synchronized:
		return

	var outer_dist := _angle_dist(_outer_angle, 0.0)
	var middle_dist := _angle_dist(_middle_angle, 0.0)
	var inner_dist := _angle_dist(_inner_angle, 0.0)

	if _outer_locked and _middle_locked and _inner_locked:
		if outer_dist <= 25.0 and middle_dist <= 25.0 and inner_dist <= 25.0:
			_trigger_grand_synchronization()


func _angle_dist(a: float, b: float) -> float:
	var diff := fmod(absf(a - b), 360.0)
	return diff if diff <= 180.0 else 360.0 - diff


func _trigger_grand_synchronization() -> void:
	is_synchronized = true
	_outer_angle = 0.0
	_middle_angle = 0.0
	_inner_angle = 0.0
	if outer_ring != null:
		outer_ring.rotation_degrees = 0.0
	if middle_ring != null:
		middle_ring.rotation_degrees = 0.0
	if inner_ring != null:
		inner_ring.rotation_degrees = 0.0

	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_clack"):
				audio.call("play_gear_clack")

			var timer := tree.create_timer(1.0)
			timer.timeout.connect(func() -> void:
				if audio != null and audio.has_method("play_grand_synchronization_toll"):
					audio.call("play_grand_synchronization_toll")

				if celebration_glow != null:
					celebration_glow.visible = true
					var tween := create_tween()
					if tween != null:
						tween.tween_property(celebration_glow, "modulate:a", 1.0, 0.5)

				if exit_portal != null:
					exit_portal.visible = true

				synchronization_completed.emit()

				var top_hint := get_node_or_null("/root/TopHintUI")
				if top_hint != null and top_hint.has_method("show_interaction_hint"):
					top_hint.call("show_interaction_hint", "tower_complete", "奥雷姆钟庭的时律已完全恢复！")
			)
	else:
		synchronization_completed.emit()


func _on_console_entered(body: Node2D, id: String) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_active_console_id = id
		var names := {"outer": "发条环", "middle": "齿轮环", "inner": "钟摆环"}
		var top_hint := get_node_or_null("/root/TopHintUI")
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", "sync_console", "按 E 锁定/释放 " + names.get(id, "") + "（对齐12点）")


func _on_console_exited(body: Node2D, id: String) -> void:
	if (body.is_in_group("player") or body.name == "Player") and _active_console_id == id:
		_active_console_id = ""
		var top_hint := get_node_or_null("/root/TopHintUI")
		if top_hint != null and top_hint.has_method("hide_hint"):
			top_hint.call("hide_hint", "sync_console")
