class_name HomeCameraDirector
extends Node

## Bedroom access is deliberately interaction-driven. The Area2D supplies the
## prompt, while the StaticBody2D physically closes the passage until E is used.

@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("Camera2D") var camera_path: NodePath
@export_node_path("CollisionShape2D") var left_barrier_path: NodePath
@export_node_path("CollisionShape2D") var right_barrier_path: NodePath
@export_node_path("Area2D") var entrance_area_path: NodePath
@export_node_path("CollisionShape2D") var entrance_collision_path: NodePath
@export_node_path("CollisionShape2D") var blocker_collision_path: NodePath
@export_node_path("Sprite2D") var barrier_visual_path: NodePath
@export var bedroom_right_limit := 256
@export_range(0.1, 1.0, 0.05) var barrier_transition_seconds := 0.35
@export_range(400.0, 5000.0, 100.0) var pan_speed := 1800.0
@export var interaction_hint_text := "按[E]进入卧室"

var _player: CharacterBody2D
var _camera: Camera2D
var _entrance_area: Area2D
var _entrance_collision: CollisionShape2D
var _blocker_collision: CollisionShape2D
var _barrier_visual: Sprite2D
var _barrier_material: ShaderMaterial
var _player_near_entrance := false
var _bedroom_active := false
var _crossed_into_bedroom := false
var _main_camera_restored := false
var _barrier_tween: Tween


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_camera = get_node_or_null(camera_path) as Camera2D
	_entrance_area = get_node_or_null(entrance_area_path) as Area2D
	_entrance_collision = get_node_or_null(entrance_collision_path) as CollisionShape2D
	_blocker_collision = get_node_or_null(blocker_collision_path) as CollisionShape2D
	_barrier_visual = get_node_or_null(barrier_visual_path) as Sprite2D
	_barrier_material = _barrier_visual.material as ShaderMaterial if _barrier_visual != null else null
	if _player == null or _camera == null or _entrance_area == null or _entrance_collision == null or _blocker_collision == null or _barrier_material == null:
		push_error("HomeCameraDirector is missing a required bedroom entrance node.")
		set_process(false)
		return
	_entrance_area.body_entered.connect(_on_entrance_body_entered)
	_entrance_area.body_exited.connect(_on_entrance_body_exited)
	_camera.top_level = false
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = pan_speed
	_camera.limit_smoothed = true
	_apply_camera_limits(false)
	_set_barrier_dissolve(0.0)


func _process(_delta: float) -> void:
	if not _bedroom_active or _player == null:
		return
	if not _crossed_into_bedroom and _player.global_position.x < 0.0:
		_crossed_into_bedroom = true
		_apply_camera_limits(true)
		return
	if _crossed_into_bedroom and not _main_camera_restored and _player.global_position.x >= 0.0:
		_main_camera_restored = true
		_apply_camera_limits(false)
	if _player.global_position.x > _main_room_side_x():
		_return_to_main_room()


func _input(event: InputEvent) -> void:
	if get_tree().has_meta("day_modal_input_locked") or _bedroom_active or not _player_near_entrance or not _is_interact_event(event):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	_enter_bedroom()


func _enter_bedroom() -> void:
	_bedroom_active = true
	_crossed_into_bedroom = false
	_main_camera_restored = false
	_player_near_entrance = false
	_hide_interaction_hint()
	_entrance_area.set_deferred("monitoring", false)
	_entrance_collision.set_deferred("disabled", true)
	_blocker_collision.set_deferred("disabled", true)
	_animate_barrier(1.0)


func _return_to_main_room() -> void:
	_bedroom_active = false
	_crossed_into_bedroom = false
	_main_camera_restored = false
	_entrance_collision.set_deferred("disabled", false)
	_blocker_collision.set_deferred("disabled", false)
	_entrance_area.set_deferred("monitoring", true)
	_apply_camera_limits(false)
	_animate_barrier(0.0)


func _on_entrance_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body == _player and not _bedroom_active:
		_player_near_entrance = true
		_show_interaction_hint()


func _on_entrance_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body == _player:
		_player_near_entrance = false
		_hide_interaction_hint()


func _apply_camera_limits(is_bedroom: bool) -> void:
	_camera.limit_left = roundi(_inner_edge(left_barrier_path, true)) if is_bedroom else 0
	_camera.limit_right = bedroom_right_limit if is_bedroom else roundi(_inner_edge(right_barrier_path, false))
	# The one permanent Player/Camera2D owns all motion. Switching limits gives
	# Godot a new target while its fixed smoothing settings perform the pan.
	_camera.top_level = false
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = pan_speed
	_camera.limit_smoothed = true


func _animate_barrier(target_dissolve: float) -> void:
	if _barrier_tween != null and _barrier_tween.is_valid():
		_barrier_tween.kill()
	if target_dissolve < 1.0:
		_barrier_visual.visible = true
	_barrier_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_barrier_tween.tween_method(_set_barrier_dissolve, _barrier_material.get_shader_parameter("dissolve"), target_dissolve, barrier_transition_seconds)
	if target_dissolve >= 1.0:
		_barrier_tween.tween_callback(_hide_barrier_visual)


func _set_barrier_dissolve(value: float) -> void:
	_barrier_material.set_shader_parameter("dissolve", value)


func _hide_barrier_visual() -> void:
	_barrier_visual.visible = false


func _bedroom_side_x() -> float:
	return _blocker_collision.global_position.x - _blocker_half_width() - 40.0


func _main_room_side_x() -> float:
	return _blocker_collision.global_position.x + _blocker_half_width() + 40.0


func _blocker_half_width() -> float:
	var rectangle := _blocker_collision.shape as RectangleShape2D
	return rectangle.size.x * 0.5 if rectangle != null else 0.0


func _inner_edge(barrier_path: NodePath, is_left: bool) -> float:
	var collision_shape := get_node_or_null(barrier_path) as CollisionShape2D
	if collision_shape == null or not collision_shape.shape is RectangleShape2D:
		push_error("HomeCameraDirector barrier is missing or is not rectangular: %s" % barrier_path)
		return 0.0
	var rectangle := collision_shape.shape as RectangleShape2D
	var half_width := rectangle.size.x * 0.5
	return collision_shape.global_position.x + half_width if is_left else collision_shape.global_position.x - half_width


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E)


func _show_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return null


func _hint_id() -> String:
	return "bedroom_entrance_%s" % get_instance_id()
