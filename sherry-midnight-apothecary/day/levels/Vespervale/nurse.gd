class_name NursePatrol
extends CharacterBody2D

## Nurse Patrol AI for Vespervale Inner (Upper Hallway).
## Patrols the 4 curtains in specific sequence: 2 -> 1 -> 4 -> 3.
## Holds a lantern with spotlight; catches unhidden Luca and resets him to Curtain 1.

signal luca_spotted(luca_body: Node2D)
signal patrol_loop_restarted

enum PatrolState {
	SPAWN,
	WALKING_TO_CURTAIN,
	INSPECTING_CURTAIN,
	EXITING_RIGHT,
	RESETTING
}

@export var move_speed: float = 120.0
@export var inspect_duration: float = 2.0
@export var spawn_x: float = 1750.0
@export var exit_x: float = 1850.0
@export var patrol_floor_y: float = 300.0
@export var hide_detection_radius: float = 48.0

## Patrol sequence: Curtain2 -> Curtain1 -> Curtain4 -> Curtain3
@export var curtain_sequence: Array[int] = [2, 1, 4, 3]

var current_state: PatrolState = PatrolState.SPAWN
var current_step_index: int = 0
var _inspect_timer: float = 0.0
var _curtain_nodes: Dictionary = {} # int -> Node2D
var _curtain_1_pos: Vector2 = Vector2(175, 300)
var _is_resetting_player: bool = false
var _lantern_base_x: float = 85.0
var _base_light_scale: Vector2 = Vector2(1.18, 1.18)

@onready var sprite: Node2D = get_node_or_null("NurseSprite")
@onready var lantern_pivot: Node2D = get_node_or_null("LanternPivot")
@onready var lantern_area: Area2D = get_node_or_null("LanternPivot/LanternSpotArea")
@onready var lantern_light: Sprite2D = get_node_or_null("LanternPivot/LanternLightVisual")
@onready var fade_rect: ColorRect = get_node_or_null("CanvasLayer/FadeRect")


func _ready() -> void:
	add_to_group("nurse_hazard")
	if lantern_pivot != null:
		_lantern_base_x = absf(lantern_pivot.position.x)
	if lantern_light != null:
		_base_light_scale = lantern_light.scale
	_discover_curtains()
	global_position = Vector2(spawn_x, patrol_floor_y)
	if lantern_area != null:
		lantern_area.body_entered.connect(_on_lantern_body_entered)
	_start_patrol_loop()


func _discover_curtains() -> void:
	_curtain_nodes.clear()
	var root := get_tree().current_scene
	if root == null:
		return

	# Search in World/Props/curtain or scene-wide
	for i in [1, 2, 3, 4]:
		var node_path := "World/Props/curtain/Curtain%d" % i
		var curtain := root.get_node_or_null(node_path) as Node2D
		if curtain == null:
			curtain = root.find_child("Curtain%d" % i, true, false) as Node2D
		if curtain != null:
			_curtain_nodes[i] = curtain
			if i == 1:
				_curtain_1_pos = curtain.global_position

	if _curtain_nodes.has(1):
		_curtain_1_pos = _curtain_nodes[1].global_position


func _physics_process(delta: float) -> void:
	if _is_resetting_player:
		velocity = Vector2.ZERO
		return

	# Continuous feedback, breathing pulse and lantern detection
	_update_luca_hiding_visuals()
	_pulse_lantern_light(delta)
	_check_lantern_detection()

	match current_state:
		PatrolState.SPAWN:
			current_step_index = 0
			_move_to_next_curtain()

		PatrolState.WALKING_TO_CURTAIN:
			var target_x := _get_current_target_x()
			var dist := target_x - global_position.x
			if absf(dist) <= 8.0:
				global_position.x = target_x
				velocity.x = 0.0
				_start_inspecting()
			else:
				var dir := signf(dist)
				velocity.x = dir * move_speed
				_update_facing(dir)
				move_and_slide()

		PatrolState.INSPECTING_CURTAIN:
			velocity.x = 0.0
			_inspect_timer -= delta
			_pulse_lantern_light(delta)
			if _inspect_timer <= 0.0:
				current_step_index += 1
				if current_step_index < curtain_sequence.size():
					_move_to_next_curtain()
				else:
					_start_exiting_right()

		PatrolState.EXITING_RIGHT:
			var dir := 1.0
			velocity.x = dir * move_speed
			_update_facing(dir)
			move_and_slide()
			if global_position.x >= exit_x:
				# Loop immediately: restart patrol cycle from right
				_start_patrol_loop()


func _update_luca_hiding_visuals() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var luca := root.get_node_or_null("Luca") as Node2D
	if luca != null and is_instance_valid(luca):
		var hidden := is_luca_hidden(luca)
		var target_modulate := Color(0.7, 0.75, 0.9, 0.7) if hidden else Color(1.0, 1.0, 1.0, 1.0)
		luca.modulate = luca.modulate.lerp(target_modulate, 0.15)
		luca.z_index = 10 if hidden else 12


func _start_patrol_loop() -> void:
	global_position = Vector2(spawn_x, patrol_floor_y)
	current_step_index = 0
	current_state = PatrolState.WALKING_TO_CURTAIN
	if sprite is AnimatedSprite2D and not (sprite as AnimatedSprite2D).is_playing():
		(sprite as AnimatedSprite2D).play("walk")
	patrol_loop_restarted.emit()


func _move_to_next_curtain() -> void:
	current_state = PatrolState.WALKING_TO_CURTAIN
	if sprite is AnimatedSprite2D and not (sprite as AnimatedSprite2D).is_playing():
		(sprite as AnimatedSprite2D).play("walk")


func _start_inspecting() -> void:
	current_state = PatrolState.INSPECTING_CURTAIN
	_inspect_timer = inspect_duration
	if sprite is AnimatedSprite2D:
		(sprite as AnimatedSprite2D).pause()


func _start_exiting_right() -> void:
	current_state = PatrolState.EXITING_RIGHT
	if sprite is AnimatedSprite2D and not (sprite as AnimatedSprite2D).is_playing():
		(sprite as AnimatedSprite2D).play("walk")


func _get_current_target_x() -> float:
	if current_step_index < curtain_sequence.size():
		var curtain_id := curtain_sequence[current_step_index]
		if _curtain_nodes.has(curtain_id) and is_instance_valid(_curtain_nodes[curtain_id]):
			return _curtain_nodes[curtain_id].global_position.x
	return spawn_x


func _update_facing(dir: float) -> void:
	if is_zero_approx(dir):
		return

	# Correct nurse sprite facing direction
	if sprite != null:
		sprite.flip_h = dir < 0.0

	# Synchronously flip lantern pivot position and scale
	if lantern_pivot != null:
		var sign_val := -1.0 if dir < 0.0 else 1.0
		lantern_pivot.position.x = _lantern_base_x * sign_val
		lantern_pivot.scale.x = sign_val


func _pulse_lantern_light(_delta: float) -> void:
	if lantern_light != null:
		var is_inspecting := (current_state == PatrolState.INSPECTING_CURTAIN)
		var breath_speed := 0.005 if is_inspecting else 0.0032
		var pulse := (sin(Time.get_ticks_msec() * breath_speed) + 1.0) * 0.5
		var min_alpha := 0.75 if is_inspecting else 0.65
		var max_alpha := 0.98 if is_inspecting else 0.88
		lantern_light.modulate.a = lerpf(min_alpha, max_alpha, pulse)
		var scale_factor := lerpf(0.92, 1.10, pulse)
		lantern_light.scale = _base_light_scale * scale_factor


func _on_lantern_body_entered(body: Node2D) -> void:
	if body != null and (body.name == "Luca" or (body.is_in_group("player") and body.name != "Player")):
		_handle_luca_detected(body)


func _check_lantern_detection() -> void:
	if _is_resetting_player or lantern_area == null:
		return

	for body in lantern_area.get_overlapping_bodies():
		if body != null and (body.name == "Luca" or (body.has_method("is_airborne") and body.name != "Player")):
			if not is_luca_hidden(body):
				_handle_luca_detected(body)
				break


func is_luca_hidden(luca_body: Node2D) -> bool:
	if luca_body == null:
		return false

	var luca_x := luca_body.global_position.x
	for curtain_id in _curtain_nodes:
		var curtain: Node2D = _curtain_nodes[curtain_id]
		if is_instance_valid(curtain):
			var dist := absf(luca_x - curtain.global_position.x)
			if dist <= hide_detection_radius:
				# Luca is hidden behind this curtain
				return true
	return false


func _handle_luca_detected(luca_body: Node2D) -> void:
	if _is_resetting_player:
		return
	if is_luca_hidden(luca_body):
		return

	_is_resetting_player = true
	luca_spotted.emit(luca_body)

	# Disable Luca input during black screen reset
	if luca_body.has_method("set_control_enabled"):
		luca_body.call("set_control_enabled", false)

	# Play black screen fade out -> reset -> fade in
	if fade_rect != null:
		fade_rect.visible = true
		fade_rect.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(fade_rect, "modulate:a", 1.0, 0.35)
		tw.tween_callback(func() -> void:
			# Reset Luca position to Curtain 1
			if _curtain_nodes.has(1) and is_instance_valid(_curtain_nodes[1]):
				_curtain_1_pos = _curtain_nodes[1].global_position
			luca_body.global_position = Vector2(_curtain_1_pos.x, patrol_floor_y)
			if luca_body is CharacterBody2D:
				(luca_body as CharacterBody2D).velocity = Vector2.ZERO
			if luca_body.has_method("reset_physics_interpolation"):
				luca_body.call("reset_physics_interpolation")

			# Reset nurse patrol cycle back to the right
			_start_patrol_loop()
		)
		tw.tween_interval(0.2)
		tw.tween_property(fade_rect, "modulate:a", 0.0, 0.45)
		tw.tween_callback(func() -> void:
			fade_rect.visible = false
			_is_resetting_player = false
			if is_instance_valid(luca_body) and luca_body.has_method("set_control_enabled"):
				luca_body.call("set_control_enabled", true)
		)
	else:
		# Fallback instant reset
		if _curtain_nodes.has(1) and is_instance_valid(_curtain_nodes[1]):
			_curtain_1_pos = _curtain_nodes[1].global_position
		luca_body.global_position = Vector2(_curtain_1_pos.x, patrol_floor_y)
		_start_patrol_loop()
		_is_resetting_player = false
		if luca_body.has_method("set_control_enabled"):
			luca_body.call("set_control_enabled", true)
