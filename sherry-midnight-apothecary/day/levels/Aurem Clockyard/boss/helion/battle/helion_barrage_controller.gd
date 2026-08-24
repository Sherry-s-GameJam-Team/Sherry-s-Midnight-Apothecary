class_name HelionBarrageController
extends Node2D

## Helion Boss Barrage & Projectile Controller
## Manages all barrage patterns, projectiles, drops, and celestial shockwaves
## using the four canonical clockyard assets:
## - gear.png (Single spinning golden gear bullets)
## - gear_cluster.png (Heavy crashing gear clusters)
## - ChatGPT Image 2026年8月19日 22_03_43.png (Celestial Sun Dial Burst)
## - ChatGPT Image 2026年8月19日 22_16_26.png (Astrolabe Shockwave Ring)

const TEX_GEAR := preload("res://day/levels/Aurem Clockyard/src/gear.png")
const TEX_GEAR_CLUSTER := preload("res://day/levels/Aurem Clockyard/src/mechanisms/gear_cluster.png")
const TEX_CELESTIAL_DIAL := preload("res://day/levels/Aurem Clockyard/src/svg/ChatGPT Image 2026年8月19日 22_03_43.png")
const TEX_ASTROLABE := preload("res://day/levels/Aurem Clockyard/src/svg/ChatGPT Image 2026年8月19日 22_16_26.png")

var _boss: Node2D = null


func setup(boss: Node2D) -> void:
	_boss = boss


# ─── Pattern 1: Aimed Fan Gear Barrage (gear.png) ───

func spawn_aimed_gear_fan(from_pos: Vector2, target_pos: Vector2, count: int = 5, spread_deg: float = 40.0, speed: float = 360.0, damage: int = 12) -> void:
	var base_dir := (target_pos - from_pos).normalized()
	if base_dir.length_squared() < 0.001:
		base_dir = Vector2.DOWN
	var base_angle := base_dir.angle()

	var start_angle := base_angle - deg_to_rad(spread_deg * 0.5)
	var step_angle := deg_to_rad(spread_deg) / float(maxi(1, count - 1)) if count > 1 else 0.0

	for i in range(count):
		var angle := start_angle + step_angle * i if count > 1 else base_angle
		var dir := Vector2.from_angle(angle)
		_spawn_gear_bullet(from_pos, dir, speed, damage, 18.0)


# ─── Pattern 2: 12-Hour Clock Burst (gear.png) ───

func spawn_12_clock_burst(from_pos: Vector2, speed: float = 320.0, damage: int = 10, angle_offset_deg: float = 0.0) -> void:
	for i in range(12):
		var angle := deg_to_rad(float(i) * 30.0 + angle_offset_deg)
		var dir := Vector2.from_angle(angle)
		_spawn_gear_bullet(from_pos, dir, speed, damage, 18.0)


# ─── Pattern 3: Spiral Stream (gear.png) ───

func spawn_spiral_stream(from_pos: Vector2, wave_count: int = 8, delay_between: float = 0.08, damage: int = 10) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for w in range(wave_count):
		var base_deg := float(w) * 25.0
		for arm in range(3):
			var angle := deg_to_rad(base_deg + float(arm) * 120.0)
			var dir := Vector2.from_angle(angle)
			_spawn_gear_bullet(from_pos, dir, 300.0, damage, 18.0)
		await tree.create_timer(delay_between).timeout


# ─── Pattern 4: Heavy Gear Cluster Drop (gear_cluster.png) ───

func spawn_heavy_gear_drop(target_floor_pos: Vector2, warning_time: float = 1.0, damage: int = 16) -> void:
	# 1. Create telegraph warning beam on the ground (top_level in global space)
	var telegraph := Node2D.new()
	telegraph.top_level = true
	telegraph.global_position = target_floor_pos
	add_child(telegraph)

	var warning_line := Line2D.new()
	warning_line.points = PackedVector2Array([Vector2(0, -600), Vector2(0, 0)])
	warning_line.width = 3.0
	warning_line.default_color = Color(1.0, 0.2, 0.2, 0.7)
	telegraph.add_child(warning_line)

	var warning_circle := Sprite2D.new()
	warning_circle.texture = TEX_GEAR
	warning_circle.scale = Vector2(0.3, 0.15)
	warning_circle.modulate = Color(1.0, 0.1, 0.1, 0.5)
	telegraph.add_child(warning_circle)

	# Pulse telegraph
	var tw := create_tween()
	if tw != null:
		tw.tween_property(warning_circle, "modulate:a", 1.0, warning_time * 0.5)
		tw.tween_property(warning_circle, "modulate:a", 0.3, warning_time * 0.5)

	var tree := get_tree()
	if tree != null:
		await tree.create_timer(warning_time).timeout

	if is_instance_valid(telegraph):
		telegraph.queue_free()

	# 2. Spawn falling gear cluster in global space
	var cluster := Area2D.new()
	cluster.top_level = true
	cluster.collision_layer = 0
	cluster.collision_mask = 1
	cluster.global_position = Vector2(target_floor_pos.x, target_floor_pos.y - 650.0)

	var spr := Sprite2D.new()
	spr.texture = TEX_GEAR_CLUSTER
	spr.scale = Vector2(0.65, 0.65)
	cluster.add_child(spr)

	var col := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = 36.0
	col.shape = circle_shape
	cluster.add_child(col)

	add_child(cluster)

	# Falling tween with impact
	var fall_tw := create_tween()
	if fall_tw != null:
		fall_tw.tween_property(cluster, "global_position:y", target_floor_pos.y - 15.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall_tw.parallel().tween_property(spr, "rotation", 6.28, 0.45)
		fall_tw.finished.connect(func() -> void:
			_on_cluster_impact(cluster.global_position, damage)
			if is_instance_valid(cluster):
				cluster.queue_free()
		)

	cluster.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") or b.name == "Player":
			_apply_damage(damage, &"helion_gear_cluster")
	)


func _on_cluster_impact(pos: Vector2, damage: int) -> void:
	# Spawn 2 low rolling mini-gears left and right along the floor
	_spawn_gear_bullet(pos, Vector2(-1.0, -0.15), 350.0, damage - 4, 16.0)
	_spawn_gear_bullet(pos, Vector2(1.0, -0.15), 350.0, damage - 4, 16.0)

	if is_inside_tree() and get_tree() != null:
		var audio: Node = get_tree().get_first_node_in_group("clocktower_audio")
		if audio != null and audio.has_method("play_gear_clack"):
			audio.call("play_gear_clack")


# ─── Pattern 5: Celestial Sun Dial Burst (ChatGPT Image 2026年8月19日 22_03_43.png) ───

func spawn_celestial_dial_burst(from_pos: Vector2, damage: int = 15) -> void:
	var dial := Area2D.new()
	dial.top_level = true
	dial.collision_layer = 0
	dial.collision_mask = 1
	dial.global_position = from_pos

	var spr := Sprite2D.new()
	spr.texture = TEX_CELESTIAL_DIAL
	spr.scale = Vector2(0.1, 0.1)
	spr.modulate = Color(1.3, 1.15, 0.7, 0.9)
	dial.add_child(spr)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 45.0
	col.shape = circle
	dial.add_child(col)

	add_child(dial)

	var tw := create_tween()
	if tw != null:
		tw.tween_property(spr, "scale", Vector2(0.55, 0.55), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(spr, "rotation", 3.14, 0.9)
		tw.tween_property(spr, "modulate:a", 0.0, 0.4)
		tw.finished.connect(func() -> void:
			if is_instance_valid(dial):
				dial.queue_free()
		)

	dial.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") or b.name == "Player":
			_apply_damage(damage, &"helion_celestial_dial")
	)

	# Also fire 6 radiating mini-gears
	for i in range(6):
		var dir := Vector2.from_angle(float(i) * 1.047)
		_spawn_gear_bullet(from_pos, dir, 280.0, damage - 3, 16.0)


# ─── Pattern 6: Astrolabe Radial Shockwave (ChatGPT Image 2026年8月19日 22_16_26.png) ───

func spawn_astrolabe_shockwave(from_pos: Vector2, damage: int = 14) -> void:
	var wave := Area2D.new()
	wave.top_level = true
	wave.collision_layer = 0
	wave.collision_mask = 1
	wave.global_position = from_pos

	var spr := Sprite2D.new()
	spr.texture = TEX_ASTROLABE
	spr.scale = Vector2(0.15, 0.15)
	spr.modulate = Color(1.1, 0.9, 0.5, 0.85)
	wave.add_child(spr)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 60.0
	col.shape = circle
	wave.add_child(col)

	add_child(wave)

	var tw := create_tween()
	if tw != null:
		# Expand shockwave outward
		tw.tween_property(spr, "scale", Vector2(0.8, 0.8), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(circle, "radius", 140.0, 1.2)
		tw.parallel().tween_property(spr, "rotation", -4.0, 1.2)
		tw.tween_property(spr, "modulate:a", 0.0, 0.3)
		tw.finished.connect(func() -> void:
			if is_instance_valid(wave):
				wave.queue_free()
		)

	wave.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") or b.name == "Player":
			_apply_damage(damage, &"helion_astrolabe_wave")
	)


# ─── Internal Helper: Gear Bullet Spawner ───

func _spawn_gear_bullet(pos: Vector2, dir: Vector2, speed: float, damage: int, radius: float) -> void:
	var bullet := Area2D.new()
	bullet.top_level = true
	bullet.collision_layer = 0
	bullet.collision_mask = 1
	bullet.global_position = pos

	var spr := Sprite2D.new()
	spr.texture = TEX_GEAR
	spr.scale = Vector2(0.38, 0.38)
	spr.modulate = Color(1.15, 0.95, 0.6, 1.0)
	bullet.add_child(spr)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	col.shape = circle
	bullet.add_child(col)

	add_child(bullet)

	var vel := dir.normalized() * speed
	var spin_speed := randf_range(6.0, 10.0)
	var lifetime := 4.5

	bullet.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") or b.name == "Player":
			_apply_damage(damage, &"helion_gear_bullet")
			if is_instance_valid(bullet):
				bullet.queue_free()
	)

	# Drive movement in global coordinates
	var move_tw := create_tween()
	if move_tw != null:
		move_tw.tween_property(bullet, "global_position", pos + vel * lifetime, lifetime)
		move_tw.parallel().tween_property(spr, "rotation", spr.rotation + spin_speed * lifetime, lifetime)
		move_tw.finished.connect(func() -> void:
			if is_instance_valid(bullet):
				bullet.queue_free()
		)


func _apply_damage(amount: int, source_id: StringName) -> void:
	if _boss != null and _boss.has_method("deal_damage_to_player"):
		_boss.call("deal_damage_to_player", amount, source_id)
	else:
		var current: Node = self
		while current != null:
			if current.has_method("apply_player_damage"):
				current.call("apply_player_damage", amount, source_id)
				return
			current = current.get_parent()
		var runtime := get_node_or_null("/root/DayRuntime")
		if runtime != null and runtime.has_method("apply_player_damage"):
			runtime.call("apply_player_damage", amount, source_id)
