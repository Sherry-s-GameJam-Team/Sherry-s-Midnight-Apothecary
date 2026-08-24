class_name TowerTopSynchronizer
extends Node2D

## Tower Top: Grand Synchronization Device (塔顶三环大校时台)
## 单一统一交互终端：无论哪个齿轮环转动至 12 点钟时点击均判定为锁定；
## 若按压时无任何未锁定环处于 12 点判定区，则全部解除锁定重置。
## 圆环采用大小不一的 gear.png 齿轮。

signal synchronization_completed

@export var is_synchronized: bool = false
@export var activate_elevator: bool = true

const HIT_WINDOW_DEG: float = 30.0

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

@onready var outer_gear_spr: Sprite2D = get_node_or_null("DialBase/OuterRing/GearSprite")
@onready var middle_gear_spr: Sprite2D = get_node_or_null("DialBase/MiddleRing/GearSprite")
@onready var inner_gear_spr: Sprite2D = get_node_or_null("DialBase/InnerRing/GearSprite")

@onready var sync_console_area: Area2D = get_node_or_null("Consoles/SyncConsole")
@onready var exit_portal: Node2D = get_node_or_null("ExitPortal")
@onready var celebration_glow: Sprite2D = get_node_or_null("CelebrationGlow")

var _player_at_console: bool = false


func _ready() -> void:
	if sync_console_area == null:
		sync_console_area = get_node_or_null("SyncConsoleArea")
	if sync_console_area == null:
		# Fallback to middle console if single console node is placed there
		sync_console_area = get_node_or_null("Consoles/MiddleLockConsole")

	if sync_console_area != null:
		sync_console_area.body_entered.connect(_on_console_entered)
		sync_console_area.body_exited.connect(_on_console_exited)

	if exit_portal != null:
		exit_portal.visible = false
	if celebration_glow != null:
		celebration_glow.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_synchronized:
		return
	if _player_at_console and event.is_action_pressed("interact"):
		attempt_lock_at_12()
		get_viewport().set_input_as_handled()


## 核心判定：无论哪个齿轮环到达 12 点（0° 附近），点击即锁定；若落空则全部解锁重置
func attempt_lock_at_12() -> void:
	if is_synchronized:
		return

	var outer_hit := not _outer_locked and _angle_dist(_outer_angle, 0.0) <= HIT_WINDOW_DEG
	var middle_hit := not _middle_locked and _angle_dist(_middle_angle, 0.0) <= HIT_WINDOW_DEG
	var inner_hit := not _inner_locked and _angle_dist(_inner_angle, 0.0) <= HIT_WINDOW_DEG

	if outer_hit or middle_hit or inner_hit:
		if outer_hit:
			_outer_locked = true
			_outer_angle = 0.0
		if middle_hit:
			_middle_locked = true
			_middle_angle = 0.0
		if inner_hit:
			_inner_locked = true
			_inner_angle = 0.0

		_play_clack_audio()
		_update_gear_visuals()

		var locked_count := (1 if _outer_locked else 0) + (1 if _middle_locked else 0) + (1 if _inner_locked else 0)
		if _outer_locked and _middle_locked and _inner_locked:
			_trigger_grand_synchronization()
		else:
			var top_hint := _find_top_hint()
			if top_hint != null and top_hint.has_method("show_interaction_hint"):
				top_hint.call("show_interaction_hint", "sync_console", "锁定成功！已锁定 (%d/3) 齿轮环" % locked_count)
	else:
		# 落空：全部解除锁定
		_outer_locked = false
		_middle_locked = false
		_inner_locked = false
		_play_miss_audio()
		_flash_fail_visuals()

		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", "sync_console", "时机未准！所有齿轮环已重置释放")


func toggle_ring_lock(ring_id: String) -> void:
	# 兼容接口
	attempt_lock_at_12()


func receive_potion_hit(hit: Dictionary) -> void:
	if PotionCapabilityResolver.hit_has_capability(hit, &"freeze"):
		# 冰药水直接三环归正并全部锁定
		_outer_angle = 0.0
		_middle_angle = 0.0
		_inner_angle = 0.0
		_outer_locked = true
		_middle_locked = true
		_inner_locked = true
		_update_gear_visuals()
		_trigger_grand_synchronization()
	elif PotionCapabilityResolver.hit_has_capability(hit, &"machine_drive") or PotionCapabilityResolver.hit_has_capability(hit, &"impact"):
		attempt_lock_at_12()


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


func _update_gear_visuals() -> void:
	if outer_gear_spr != null:
		outer_gear_spr.modulate = Color(1.5, 1.3, 0.7) if _outer_locked else Color(1.1, 0.9, 0.6)
	if middle_gear_spr != null:
		middle_gear_spr.modulate = Color(1.5, 1.3, 0.7) if _middle_locked else Color(0.95, 0.8, 0.5)
	if inner_gear_spr != null:
		inner_gear_spr.modulate = Color(1.5, 1.3, 0.7) if _inner_locked else Color(1.2, 1.0, 0.6)


func _flash_fail_visuals() -> void:
	for spr in [outer_gear_spr, middle_gear_spr, inner_gear_spr]:
		if spr != null:
			var tween: Tween = create_tween()
			if tween != null:
				tween.tween_property(spr, "modulate", Color(1.5, 0.4, 0.4), 0.15)
				tween.tween_property(spr, "modulate", Color(1.0, 0.9, 0.6), 0.25)


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

	_update_gear_visuals()

	# Elevator is currently kept hidden / dormant
	if activate_elevator:
		var elevator_node: Node = get_node_or_null("TowerElevator")
		if elevator_node == null:
			elevator_node = get_node_or_null("../TowerElevator")
		if elevator_node == null and get_parent() != null:
			elevator_node = get_parent().get_node_or_null("TowerElevator")
		if elevator_node != null and elevator_node.has_method("unlock_and_activate"):
			elevator_node.call("unlock_and_activate")

	synchronization_completed.emit()

	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			_play_clack_audio()

			var timer := tree.create_timer(0.8)
			timer.timeout.connect(func() -> void:
				var audio: Node = tree.get_first_node_in_group("clocktower_audio")
				if audio != null and audio.has_method("play_grand_synchronization_toll"):
					audio.call("play_grand_synchronization_toll")

				if celebration_glow != null:
					celebration_glow.visible = true
					var tween: Tween = create_tween()
					if tween != null:
						tween.tween_property(celebration_glow, "modulate:a", 1.0, 0.6)

				var top_hint := _find_top_hint()
				if top_hint != null and top_hint.has_method("show_interaction_hint"):
					top_hint.call("show_interaction_hint", "tower_complete", "三环齿轮校准成功！前往第6层塔顶的升降电梯已启动！")
					if tree != null:
						tree.create_timer(4.0).timeout.connect(func() -> void:
							var hint := _find_top_hint()
							if hint != null and hint.has_method("hide_interaction_hint"):
								hint.call("hide_interaction_hint", "tower_complete")
						)
			)


func _play_clack_audio() -> void:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_clack"):
				audio.call("play_gear_clack")


func _play_miss_audio() -> void:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_grind_warning"):
				audio.call("play_gear_grind_warning")


func _on_console_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_at_console = true
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", "sync_console", "按 E 锁定12点齿轮环（未对准将重置全环）")


func _on_console_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_at_console = false
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("hide_interaction_hint"):
			top_hint.call("hide_interaction_hint", "sync_console")


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
