class_name BloodRainController
extends Node2D

@export var arena_min_x := 380.0
@export var arena_max_x := 1620.0
@export var strike_y_top := -100.0
@export var strike_y_ground := 630.0
@export var warning_duration := 1.2
@export var strike_duration := 0.7
@export var damage_amount := 10
@export var strike_interval := 3.6

var _active := false
var _timer := 0.0


func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = strike_interval
		spawn_strike_wave()


func start_rain() -> void:
	_active = true
	_timer = 0.8


func stop_rain() -> void:
	_active = false
	# Cancel any pending strikes
	for child in get_children():
		child.queue_free()


func spawn_strike_wave() -> void:
	var count := randi_range(3, 4)
	var x_positions: Array[float] = []
	var segment_width := (arena_max_x - arena_min_x) / float(count)
	for i in range(count):
		var min_x := arena_min_x + i * segment_width + 40.0
		var max_x := arena_min_x + (i + 1) * segment_width - 40.0
		x_positions.append(randf_range(min_x, max_x))
	
	for target_x in x_positions:
		_spawn_single_column(target_x)


func _spawn_single_column(target_x: float) -> void:
	var column := Node2D.new()
	column.position = Vector2(target_x, 0.0)
	add_child(column)

	# 1. Warning visuals: thin red vertical line + ground oval
	var warn_line := Line2D.new()
	warn_line.width = 2.0
	warn_line.default_color = Color(1.0, 0.2, 0.3, 0.6)
	warn_line.points = PackedVector2Array([Vector2(0, strike_y_top), Vector2(0, strike_y_ground)])
	column.add_child(warn_line)

	var warn_ground := Polygon2D.new()
	warn_ground.polygon = _make_oval_polygon(Vector2(0, strike_y_ground), 32.0, 10.0, 16)
	warn_ground.color = Color(0.85, 0.1, 0.25, 0.5)
	column.add_child(warn_ground)

	# Flash ground warning
	var warn_tween := create_tween().set_loops(3)
	warn_tween.tween_property(warn_ground, "modulate:a", 0.9, 0.2)
	warn_tween.tween_property(warn_ground, "modulate:a", 0.3, 0.2)

	await get_tree().create_timer(warning_duration).timeout
	if not is_instance_valid(column):
		return

	warn_line.queue_free()
	warn_ground.queue_free()

	# 2. Strike phase: thick magical water-jet column + hit area + particles
	var strike_line := Line2D.new()
	strike_line.width = 26.0
	strike_line.default_color = Color(0.9, 0.15, 0.25, 0.95)
	strike_line.points = PackedVector2Array([Vector2(0, strike_y_top), Vector2(0, strike_y_ground)])
	column.add_child(strike_line)

	var hit_area := Area2D.new()
	hit_area.collision_layer = 0
	hit_area.collision_mask = 1 # Sherry / Player
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28.0, strike_y_ground - strike_y_top)
	col.shape = rect
	col.position = Vector2(0, (strike_y_ground + strike_y_top) * 0.5)
	hit_area.add_child(col)
	column.add_child(hit_area)

	var splash := CPUParticles2D.new()
	splash.position = Vector2(0, strike_y_ground)
	splash.amount = 16
	splash.lifetime = 0.4
	splash.spread = 160.0
	splash.gravity = Vector2(0, 120)
	splash.initial_velocity_min = 60.0
	splash.initial_velocity_max = 140.0
	splash.scale_amount_min = 2.0
	splash.scale_amount_max = 4.0
	splash.color = Color(0.8, 0.1, 0.2, 0.8)
	splash.emitting = true
	column.add_child(splash)

	# Damage detection
	hit_area.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") or body.name == "Player":
			_apply_damage_to_player(body)
	)
	# Check immediate overlap
	for body in hit_area.get_overlapping_bodies():
		if body.is_in_group("player") or body.name == "Player":
			_apply_damage_to_player(body)

	# Fade out strike line
	var strike_tween := create_tween()
	strike_tween.tween_property(strike_line, "width", 4.0, strike_duration)
	strike_tween.parallel().tween_property(strike_line, "modulate:a", 0.0, strike_duration)
	await strike_tween.finished
	if is_instance_valid(column):
		column.queue_free()


func _apply_damage_to_player(player: Node2D) -> void:
	var runtime := _get_day_runtime()
	if runtime != null and runtime.has_method("apply_player_damage"):
		runtime.call("apply_player_damage", damage_amount, StringName("blood_rain"))
	elif player.has_method("apply_damage"):
		player.call("apply_damage", damage_amount)


func _make_oval_polygon(center: Vector2, rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := float(i) / float(segments) * TAU
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _get_day_runtime() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.has_method("apply_player_damage") or cursor.has_method("switch_to_level"):
			return cursor
		cursor = cursor.get_parent()
	return null
