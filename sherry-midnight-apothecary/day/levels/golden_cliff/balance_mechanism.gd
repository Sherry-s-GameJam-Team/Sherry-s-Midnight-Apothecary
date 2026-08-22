extends StaticBody2D

signal stabilized(mechanism_id: StringName)
signal weight_changed(side: StringName, new_weight: int)
signal balance_reset()

@export var mechanism_id: StringName = &"west_balance"

@export var left_weight: int = 0
@export var right_weight: int = 0

@export var target_left_weight: int = 2
@export var target_right_weight: int = 2

@export var initial_left_weight: int = 0
@export var initial_right_weight: int = 0

@export var min_weight: int = 0
@export var max_weight: int = 4

@export var max_tilt_angle: float = 18.0
# Optional visual-only tilt for an unsolved, empty scale. This lets a puzzle
# communicate which side needs weight without changing its actual weights.
@export_range(-45.0, 45.0, 0.5) var empty_balance_display_tilt: float = 0.0

var is_stabilized: bool = false

@onready var visual: Node2D = $Visual
@onready var beam_pivot: Node2D = $Visual/BeamPivot if has_node("Visual/BeamPivot") else null
@onready var beam: Sprite2D = $Visual/BeamPivot/Beam if has_node("Visual/BeamPivot/Beam") else ($Visual/Beam if has_node("Visual/Beam") else null)
@onready var left_pan: Node2D = $Visual/BeamPivot/LeftPan if has_node("Visual/BeamPivot/LeftPan") else ($Visual/LeftPan if has_node("Visual/LeftPan") else null)
@onready var right_pan: Node2D = $Visual/BeamPivot/RightPan if has_node("Visual/BeamPivot/RightPan") else ($Visual/RightPan if has_node("Visual/RightPan") else null)
@onready var left_hit_area: Area2D = $Visual/BeamPivot/LeftPan/HitArea if has_node("Visual/BeamPivot/LeftPan/HitArea") else null
@onready var right_hit_area: Area2D = $Visual/BeamPivot/RightPan/HitArea if has_node("Visual/BeamPivot/RightPan/HitArea") else null
@onready var center_indicator: Node2D = $Visual/CenterIndicator if has_node("Visual/CenterIndicator") else null
@onready var target_indicator: Node2D = $Visual/TargetIndicator if has_node("Visual/TargetIndicator") else null
@onready var reset_area: Area2D = $ResetArea if has_node("ResetArea") else null
@onready var reset_hint: Node2D = $ResetHint if has_node("ResetHint") else null

var _base_visual_position := Vector2.ZERO
var _base_visual_scale := Vector2.ONE
var _tilt_tween: Tween
var _stabilize_check_token: int = 0
var _player_in_reset_area: bool = false
var _rng := RandomNumberGenerator.new()

# Stone visual containers
var _left_stone_container: Node2D
var _right_stone_container: Node2D

# The pan textures contain asymmetric transparent margins. These offsets align
# their visible plates with the beam ends and keep the procedural weights on
# the actual plate surface rather than in the empty canvas area.
const BEAM_PIVOT_OFFSET := Vector2(0, -35)
const LEFT_PAN_TEXTURE_OFFSET := Vector2(20, 75)
const RIGHT_PAN_TEXTURE_OFFSET := Vector2(30, 75)
const PAN_WEIGHT_OFFSET := Vector2(0, 235)
const PAN_HIT_AREA_OFFSET := Vector2(0, 215)

func _ready() -> void:
	_base_visual_position = visual.position if visual != null else position
	_base_visual_scale = visual.scale if visual != null else scale
	_rng.randomize()
	
	_setup_subnodes_if_needed()
	_setup_hit_areas()
	_setup_reset_area()
	_setup_indicators()
	
	left_weight = initial_left_weight
	right_weight = initial_right_weight
	
	_refresh_balance(false)

func _unhandled_input(event: InputEvent) -> void:
	if is_stabilized or not _player_in_reset_area:
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		reset_balance()
		get_viewport().set_input_as_handled()

func _setup_subnodes_if_needed() -> void:
	# If scene doesn't have BeamPivot yet (e.g. instantiated from older scene structure), construct dynamically
	if beam_pivot == null and visual != null:
		beam_pivot = Node2D.new()
		beam_pivot.name = "BeamPivot"
		beam_pivot.position = BEAM_PIVOT_OFFSET
		visual.add_child(beam_pivot)
		
		if beam != null and beam.get_parent() != beam_pivot:
			beam.reparent(beam_pivot)
			beam.position = Vector2.ZERO
		if left_pan != null and left_pan.get_parent() != beam_pivot:
			left_pan.reparent(beam_pivot)
			left_pan.position = LEFT_PAN_TEXTURE_OFFSET
		if right_pan != null and right_pan.get_parent() != beam_pivot:
			right_pan.reparent(beam_pivot)
			right_pan.position = RIGHT_PAN_TEXTURE_OFFSET

	# Stone visual containers under pans
	if left_pan != null:
		if left_pan.has_node("StoneContainer"):
			_left_stone_container = left_pan.get_node("StoneContainer") as Node2D
		else:
			_left_stone_container = Node2D.new()
			_left_stone_container.name = "StoneContainer"
			_left_stone_container.position = PAN_WEIGHT_OFFSET
			left_pan.add_child(_left_stone_container)

	if right_pan != null:
		if right_pan.has_node("StoneContainer"):
			_right_stone_container = right_pan.get_node("StoneContainer") as Node2D
		else:
			_right_stone_container = Node2D.new()
			_right_stone_container.name = "StoneContainer"
			_right_stone_container.position = PAN_WEIGHT_OFFSET
			right_pan.add_child(_right_stone_container)

func _setup_hit_areas() -> void:
	# Left pan hit receiver
	if left_pan != null and left_hit_area == null:
		left_hit_area = Area2D.new()
		left_hit_area.name = "LeftHitArea"
		left_hit_area.collision_layer = 1
		left_hit_area.collision_mask = 0
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 110.0
		col.shape = shape
		col.position = PAN_HIT_AREA_OFFSET
		left_hit_area.add_child(col)
		left_pan.add_child(left_hit_area)
		left_hit_area.set_meta("side", &"left")
		left_hit_area.set_script(load("res://day/levels/golden_cliff/pan_hit_receiver.gd"))
		left_hit_area.set("mechanism", self)

	# Right pan hit receiver
	if right_pan != null and right_hit_area == null:
		right_hit_area = Area2D.new()
		right_hit_area.name = "RightHitArea"
		right_hit_area.collision_layer = 1
		right_hit_area.collision_mask = 0
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 110.0
		col.shape = shape
		col.position = PAN_HIT_AREA_OFFSET
		right_hit_area.add_child(col)
		right_pan.add_child(right_hit_area)
		right_hit_area.set_meta("side", &"right")
		right_hit_area.set_script(load("res://day/levels/golden_cliff/pan_hit_receiver.gd"))
		right_hit_area.set("mechanism", self)

func _setup_reset_area() -> void:
	if reset_area == null:
		reset_area = Area2D.new()
		reset_area.name = "ResetArea"
		reset_area.collision_layer = 0
		reset_area.collision_mask = 2 # Sherry / Player is typically layer 2 or name check
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 140.0
		col.shape = shape
		col.position = Vector2(0, 30)
		reset_area.add_child(col)
		add_child(reset_area)
	
	reset_area.body_entered.connect(_on_reset_area_body_entered)
	reset_area.body_exited.connect(_on_reset_area_body_exited)
	
	if reset_hint == null:
		reset_hint = Node2D.new()
		reset_hint.name = "ResetHint"
		reset_hint.position = Vector2(0, -90)
		reset_hint.visible = false
		
		# Procedural stone rune badge for E reset
		var badge := Polygon2D.new()
		badge.polygon = PackedVector2Array([
			Vector2(-20, -12), Vector2(20, -12), Vector2(24, 0),
			Vector2(20, 12), Vector2(-20, 12), Vector2(-24, 0)
		])
		badge.color = Color(0.18, 0.16, 0.12, 0.85)
		reset_hint.add_child(badge)
		
		var outline := Line2D.new()
		outline.points = PackedVector2Array([
			Vector2(-20, -12), Vector2(20, -12), Vector2(24, 0),
			Vector2(20, 12), Vector2(-20, 12), Vector2(-24, 0), Vector2(-20, -12)
		])
		outline.width = 2.0
		outline.default_color = Color(0.95, 0.78, 0.35, 0.9)
		reset_hint.add_child(outline)
		
		var label := Label.new()
		label.text = "E 重置"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(-30, -12)
		label.size = Vector2(60, 24)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
		reset_hint.add_child(label)
		
		add_child(reset_hint)

func _setup_indicators() -> void:
	if visual == null:
		return
	
	# Target notch indicator
	if target_indicator == null:
		target_indicator = Node2D.new()
		target_indicator.name = "TargetIndicator"
		target_indicator.position = Vector2(0, -35)
		visual.add_child(target_indicator)
		
		var target_notch := Line2D.new()
		target_notch.points = PackedVector2Array([Vector2(0, -78), Vector2(0, -100)])
		target_notch.width = 4.0
		target_notch.default_color = Color(1.0, 0.82, 0.28, 0.9)
		target_notch.begin_cap_mode = Line2D.LINE_CAP_ROUND
		target_notch.end_cap_mode = Line2D.LINE_CAP_ROUND
		target_indicator.add_child(target_notch)
		
		var target_diamond := Polygon2D.new()
		target_diamond.polygon = PackedVector2Array([
			Vector2(0, -108), Vector2(6, -100), Vector2(0, -92), Vector2(-6, -100)
		])
		target_diamond.color = Color(1.0, 0.85, 0.35, 0.95)
		target_indicator.add_child(target_diamond)

	# Central needle indicator attached to beam pivot
	if center_indicator == null and beam_pivot != null:
		center_indicator = Node2D.new()
		center_indicator.name = "CenterIndicator"
		center_indicator.position = Vector2.ZERO
		beam_pivot.add_child(center_indicator)
		
		var needle := Line2D.new()
		needle.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -75)])
		needle.width = 3.5
		needle.default_color = Color(0.96, 0.94, 0.88, 0.95)
		needle.begin_cap_mode = Line2D.LINE_CAP_ROUND
		needle.end_cap_mode = Line2D.LINE_CAP_ROUND
		center_indicator.add_child(needle)
		
		var needle_head := Polygon2D.new()
		needle_head.polygon = PackedVector2Array([
			Vector2(0, -84), Vector2(4.5, -73), Vector2(0, -70), Vector2(-4.5, -73)
		])
		needle_head.color = Color(1.0, 0.95, 0.82, 1.0)
		center_indicator.add_child(needle_head)

	_update_target_indicator_angle()

func _update_target_indicator_angle() -> void:
	if target_indicator == null:
		return
	var diff_target := float(target_right_weight - target_left_weight)
	var max_w := float(max_weight) if max_weight > 0 else 1.0
	var target_norm := clampf(diff_target / max_w, -1.0, 1.0)
	target_indicator.rotation = deg_to_rad(target_norm * max_tilt_angle)

func _on_reset_area_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		_player_in_reset_area = true
		_show_balance_hint()
		if not is_stabilized and reset_hint != null:
			reset_hint.visible = true
			var tween := reset_hint.create_tween()
			tween.tween_property(reset_hint, "modulate:a", 1.0, 0.2)

func _on_reset_area_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		_player_in_reset_area = false
		_hide_balance_hint()
		if reset_hint != null:
			var tween := reset_hint.create_tween()
			tween.tween_property(reset_hint, "modulate:a", 0.0, 0.2)
			tween.finished.connect(func(): if not _player_in_reset_area: reset_hint.visible = false)

func receive_potion_hit(hit: Dictionary) -> void:
	if is_stabilized:
		return
	
	var impact_point: Vector2 = hit.get("impact_point", global_position)
	var local_impact := to_local(impact_point)
	
	# Determine if left pan or right pan was closer to impact
	if local_impact.x < 0.0:
		add_weight(&"left", impact_point)
	else:
		add_weight(&"right", impact_point)

func apply_potion_effect(_effect_id: StringName, _context: Dictionary) -> void:
	# Direct bottle impacts calibrate the mechanism; splash effects do not affect weights.
	pass

func add_weight(side: StringName, impact_point: Vector2 = Vector2.ZERO) -> void:
	if is_stabilized:
		return
	
	match side:
		&"left":
			if left_weight >= max_weight:
				_play_capacity_blocked_feedback(&"left")
				return
			left_weight = clampi(left_weight + 1, min_weight, max_weight)
			weight_changed.emit(&"left", left_weight)
		&"right":
			if right_weight >= max_weight:
				_play_capacity_blocked_feedback(&"right")
				return
			right_weight = clampi(right_weight + 1, min_weight, max_weight)
			weight_changed.emit(&"right", right_weight)
		_:
			return

	if impact_point == Vector2.ZERO:
		impact_point = global_position
	
	_play_hit_feedback(side, impact_point)
	_refresh_balance(true)
	_show_balance_hint()
	_check_solution()

func reset_balance() -> void:
	if is_stabilized:
		return
	
	left_weight = initial_left_weight
	right_weight = initial_right_weight
	
	_refresh_balance(true)
	_show_balance_hint()
	_spawn_ring(global_position + Vector2(0, 20), Color(0.8, 0.7, 0.4, 0.7), 60.0)
	_spawn_fragments(global_position + Vector2(0, 20), 5)
	balance_reset.emit()

func _refresh_balance(animated: bool = true) -> void:
	var diff := float(right_weight - left_weight)
	var max_w := float(max_weight) if max_weight > 0 else 1.0
	var normalized := clampf(diff / max_w, -1.0, 1.0)
	var target_rotation := deg_to_rad(normalized * max_tilt_angle)
	if not is_stabilized and left_weight == initial_left_weight and right_weight == initial_right_weight:
		target_rotation = deg_to_rad(empty_balance_display_tilt)
	
	if animated and beam_pivot != null:
		if _tilt_tween != null and _tilt_tween.is_valid():
			_tilt_tween.kill()
		_tilt_tween = create_tween()
		_tilt_tween.set_parallel(true)
		_tilt_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tilt_tween.tween_property(beam_pivot, "rotation", target_rotation, 0.32)
		
		# Keep pans hanging upright relative to world
		if left_pan != null:
			_tilt_tween.tween_property(left_pan, "rotation", -target_rotation * 0.4, 0.32)
		if right_pan != null:
			_tilt_tween.tween_property(right_pan, "rotation", -target_rotation * 0.4, 0.32)
	elif beam_pivot != null:
		beam_pivot.rotation = target_rotation
		if left_pan != null:
			left_pan.rotation = -target_rotation * 0.4
		if right_pan != null:
			right_pan.rotation = -target_rotation * 0.4

	_update_weight_visuals(animated)

func _update_weight_visuals(animated: bool = true) -> void:
	_render_stones_in_container(_left_stone_container, left_weight, animated)
	_render_stones_in_container(_right_stone_container, right_weight, animated)

func _render_stones_in_container(container: Node2D, count: int, animated: bool) -> void:
	if container == null:
		return
	
	# Clear old stones
	for child in container.get_children():
		child.queue_free()
	
	# Layout positions for stone weights
	var positions: Array[Vector2] = []
	match count:
		1:
			positions = [Vector2(0, 0)]
		2:
			positions = [Vector2(-35, 0), Vector2(35, 0)]
		3:
			positions = [Vector2(-42, 5), Vector2(42, 5), Vector2(0, -32)]
		4:
			positions = [Vector2(-48, 8), Vector2(48, 8), Vector2(-24, -28), Vector2(24, -28)]
	
	for i in range(count):
		var pos := positions[i]
		var stone := Node2D.new()
		stone.position = pos
		
		var stone_poly := Polygon2D.new()
		stone_poly.polygon = PackedVector2Array([
			Vector2(-24, -12), Vector2(0, -20), Vector2(24, -12),
			Vector2(28, 12), Vector2(0, 18), Vector2(-28, 12)
		])
		stone_poly.color = Color(0.88, 0.72, 0.32, 0.95)
		stone.add_child(stone_poly)
		
		var stone_outline := Line2D.new()
		stone_outline.points = PackedVector2Array([
			Vector2(-24, -12), Vector2(0, -20), Vector2(24, -12),
			Vector2(28, 12), Vector2(0, 18), Vector2(-28, 12), Vector2(-24, -12)
		])
		stone_outline.width = 3.0
		stone_outline.default_color = Color(0.68, 0.52, 0.20, 0.9)
		stone.add_child(stone_outline)
		
		# Stone facet highlight
		var highlight := Line2D.new()
		highlight.points = PackedVector2Array([Vector2(-16, -6), Vector2(0, -12), Vector2(16, -6)])
		highlight.width = 2.0
		highlight.default_color = Color(1.0, 0.92, 0.65, 0.8)
		stone.add_child(highlight)
		
		container.add_child(stone)
		
		if animated and i == count - 1:
			stone.scale = Vector2(0.3, 0.3)
			var tween := stone.create_tween()
			tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(stone, "scale", Vector2.ONE, 0.22)

func _check_solution() -> void:
	if is_stabilized:
		return
	
	if left_weight == target_left_weight and right_weight == target_right_weight:
		_stabilize_check_token += 1
		var token := _stabilize_check_token
		
		# 0.6s delay before confirming stabilization
		await get_tree().create_timer(0.6).timeout
		if token != _stabilize_check_token or is_stabilized:
			return
		
		if left_weight == target_left_weight and right_weight == target_right_weight:
			_stabilize()

func _play_hit_feedback(side: StringName, impact_point: Vector2) -> void:
	var target_pan: Node2D = left_pan if side == &"left" else right_pan
	if target_pan != null:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(target_pan, "scale", Vector2(1.08, 0.92), 0.08)
		tween.tween_property(target_pan, "scale", Vector2.ONE, 0.15)
	
	_spawn_ring(impact_point, Color(1.0, 0.82, 0.25, 0.9), 65.0)
	_spawn_fragments(impact_point, 5)

func _play_capacity_blocked_feedback(side: StringName) -> void:
	var target_pan: Node2D = left_pan if side == &"left" else right_pan
	if target_pan != null:
		var tween := create_tween()
		tween.tween_property(target_pan, "modulate", Color(1.3, 0.6, 0.6), 0.1)
		tween.tween_property(target_pan, "modulate", Color.WHITE, 0.2)

func _stabilize() -> void:
	if is_stabilized:
		return
	is_stabilized = true
	_hide_balance_hint()
	
	if reset_hint != null:
		reset_hint.visible = false
	
	var vis := visual if visual != null else (get_node_or_null("Visual") as Node2D)
	if vis != null:
		var shake_tween := create_tween()
		if shake_tween != null:
			shake_tween.tween_property(vis, "position:x", _base_visual_position.x + 3.0, 0.04)
			shake_tween.tween_property(vis, "position:x", _base_visual_position.x - 3.0, 0.04)
			shake_tween.tween_property(vis, "position:x", _base_visual_position.x + 2.0, 0.04)
			shake_tween.tween_property(vis, "position:x", _base_visual_position.x, 0.03)
	
	var diff_target := float(target_right_weight - target_left_weight)
	var max_w := float(max_weight) if max_weight > 0 else 1.0
	var final_rotation := deg_to_rad(clampf(diff_target / max_w, -1.0, 1.0) * max_tilt_angle)
	var pivot := beam_pivot if beam_pivot != null else (get_node_or_null("Visual/BeamPivot") as Node2D)
	if pivot != null:
		var rot_tween := create_tween()
		if rot_tween != null:
			rot_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			rot_tween.tween_property(pivot, "rotation", final_rotation, 0.4)
	
	if target_indicator != null:
		var glow_tween := target_indicator.create_tween()
		if glow_tween != null:
			glow_tween.tween_property(target_indicator, "modulate", Color(1.5, 1.3, 0.7, 1.0), 0.3)
	if center_indicator != null:
		var needle_glow := center_indicator.create_tween()
		if needle_glow != null:
			needle_glow.tween_property(center_indicator, "modulate", Color(1.5, 1.4, 0.8, 1.0), 0.3)
	
	if is_inside_tree():
		_spawn_ring(global_position + Vector2(0, -10), Color(1.0, 0.92, 0.45, 1.0), 180.0)
		_spawn_fragments(global_position + Vector2(0, -10), 10)
	
	stabilized.emit(mechanism_id)

func _show_balance_hint() -> void:
	if not _player_in_reset_area or is_stabilized:
		return
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_balance_hint_id(), _balance_hint_text())

func _hide_balance_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_balance_hint_id())

func _balance_hint_text() -> String:
	var left_remaining := target_left_weight - left_weight
	var right_remaining := target_right_weight - right_weight
	if left_remaining < 0 or right_remaining < 0:
		return "衡石失衡：按 [E] 重置后重新配平"
	if left_remaining == 0 and right_remaining == 0:
		return "衡石已配平，正在稳定……"
	var steps: Array[String] = []
	if left_remaining > 0:
		steps.append("左盘 +%d" % left_remaining)
	if right_remaining > 0:
		steps.append("右盘 +%d" % right_remaining)
	return "衡石校准：%s（目标 左%d / 右%d）" % ["、".join(steps), target_left_weight, target_right_weight]

func _balance_hint_id() -> String:
	return "golden_cliff_balance_%s" % mechanism_id

func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI

func _exit_tree() -> void:
	_hide_balance_hint()

func _spawn_ring(world_position: Vector2, color: Color, radius: float) -> void:
	var ring := Line2D.new()
	ring.width = 5.5
	ring.default_color = color
	ring.closed = true
	ring.z_index = 30
	var points := PackedVector2Array()
	for index in range(33):
		var angle := TAU * float(index) / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.points = points
	
	var parent_node := get_parent() if get_parent() != null else self
	parent_node.add_child(ring)
	ring.global_position = world_position
	ring.scale = Vector2(0.2, 0.2)
	
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(2.5, 2.5), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.6)
	tween.finished.connect(ring.queue_free)

func _spawn_fragments(world_position: Vector2, count: int) -> void:
	var parent_node := get_parent() if get_parent() != null else self
	for index in range(count):
		var fragment := Polygon2D.new()
		fragment.polygon = PackedVector2Array([
			Vector2(-5, -3), Vector2(5, -4), Vector2(4, 4), Vector2(-4, 5)
		])
		fragment.color = Color(0.92, 0.68, 0.24, 0.95)
		fragment.z_index = 31
		parent_node.add_child(fragment)
		fragment.global_position = world_position
		
		var angle := _rng.randf_range(-PI * 0.95, -PI * 0.05)
		var distance := _rng.randf_range(50.0, 130.0)
		var target := world_position + Vector2(cos(angle), sin(angle)) * distance + Vector2(0, 45)
		
		var tween := fragment.create_tween()
		tween.set_parallel(true)
		tween.tween_property(fragment, "global_position", target, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(fragment, "rotation", _rng.randf_range(-3.0, 3.0), 0.55)
		tween.tween_property(fragment, "modulate:a", 0.0, 0.55)
		tween.finished.connect(fragment.queue_free)
