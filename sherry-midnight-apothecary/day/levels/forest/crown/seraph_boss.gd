class_name SeraphBoss
extends Node2D

signal corruption_changed(current: float, max_val: float)
signal boss_state_changed(new_state: BossState)
signal boss_purified_completed

enum BossState {
	INTRO,
	BLOOD_RAIN,
	PHASE1_EXPOSED,
	FEATHER_STORM,
	PHASE2_EXPOSED,
	CORRUPTION_CORE,
	FINAL_PURIFICATION,
	RESTORED
}

@export var max_corruption := 100.0
@export var damage_feather := 8
@export var damage_shockwave := 12

@onready var seraph_corrupted: Sprite2D = $SeraphSprite
@onready var seraph_normal: Sprite2D = $SeraphNormalSprite
@onready var halo_outer: CorruptionRing = $HaloOuter
@onready var halo_inner: CorruptionRing = $HaloInner
@onready var corruption_core: Node2D = $CorruptionCore
@onready var core_weakpoint: SeraphWeakpoint = $CorruptionCore/CoreWeakpoint
@onready var boss_body_area: Area2D = $BossBody
@onready var attack_origins: Node2D = $AttackOrigins
@onready var vfx_controller: CrownVFXController = get_node_or_null("../CrownVFX")
@onready var blood_rain_controller: BloodRainController = get_node_or_null("../Hazards/BloodRain")

var state := BossState.INTRO
var corruption := 100.0
var _exposed_timer := 0.0
var _attack_timer := 0.0
var _feather_pattern_index := 0
var _core_hits := 0
var _phase2_hits := 0
var _base_position := Vector2.ZERO
var _float_time := 0.0


func _ready() -> void:
	_base_position = position
	corruption = max_corruption
	add_to_group("seraph_boss")
	_setup_nodes()


func _setup_nodes() -> void:
	if halo_outer != null:
		halo_outer.ring_shattered.connect(_on_halo_outer_shattered)
	if halo_inner != null:
		halo_inner.ring_shattered.connect(_on_halo_inner_shattered)
	if core_weakpoint != null:
		core_weakpoint.weakpoint_purified.connect(_on_core_weakpoint_purified)
	if boss_body_area != null:
		boss_body_area.body_entered.connect(_on_body_entered_boss)

	# Initial visibility
	if corruption_core != null:
		corruption_core.visible = false
	if halo_outer != null:
		halo_outer.visible = false
	if halo_inner != null:
		halo_inner.visible = false


func _process(delta: float) -> void:
	# Gentle floating hover
	_float_time += delta * 1.5
	if state != BossState.PHASE1_EXPOSED and state != BossState.PHASE2_EXPOSED and state != BossState.FINAL_PURIFICATION:
		position.y = _base_position.y + sin(_float_time) * 12.0

	match state:
		BossState.BLOOD_RAIN:
			pass
		BossState.PHASE1_EXPOSED:
			_exposed_timer -= delta
			if _exposed_timer <= 0.0:
				# Re-shield if window expired without enough hits
				_enter_blood_rain_phase()
		BossState.FEATHER_STORM:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack_timer = randf_range(3.2, 4.4)
				_trigger_feather_attack()
		BossState.PHASE2_EXPOSED:
			_exposed_timer -= delta
			if _exposed_timer <= 0.0:
				_enter_feather_storm_phase()
		BossState.CORRUPTION_CORE:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack_timer = 4.2
				_trigger_shockwave_attack()


func start_encounter() -> void:
	_set_state(BossState.BLOOD_RAIN)
	_enter_blood_rain_phase()


func _enter_blood_rain_phase() -> void:
	_set_state(BossState.BLOOD_RAIN)
	if blood_rain_controller != null:
		blood_rain_controller.start_rain()
	if halo_outer != null:
		halo_outer.visible = true
		halo_outer.max_stability = 3
		halo_outer.reset_ring()
		halo_outer.spawn_weakpoints_at_radius(2, 0.0)
	if halo_inner != null:
		halo_inner.visible = false
	if corruption_core != null:
		corruption_core.visible = false


func _enter_phase1_exposed() -> void:
	_set_state(BossState.PHASE1_EXPOSED)
	_exposed_timer = 5.5
	if blood_rain_controller != null:
		blood_rain_controller.stop_rain()
	# Swoop down slightly in exhaustion
	var tween := create_tween()
	tween.tween_property(self, "position:y", _base_position.y + 35.0, 0.5)


func _enter_feather_storm_phase() -> void:
	_set_state(BossState.FEATHER_STORM)
	_phase2_hits = 0
	_attack_timer = 1.5
	if blood_rain_controller != null:
		blood_rain_controller.stop_rain()
	var tween := create_tween()
	tween.tween_property(self, "position:y", _base_position.y, 0.5)

	# Setup dual rotating rings
	if halo_outer != null:
		halo_outer.visible = true
		halo_outer.ring_radius = 170.0
		halo_outer.rotation_speed = 0.75
		halo_outer.reset_ring()
		halo_outer.spawn_weakpoints_at_radius(2, 0.0)
	if halo_inner != null:
		halo_inner.visible = true
		halo_inner.ring_radius = 110.0
		halo_inner.rotation_speed = -1.1
		halo_inner.reset_ring()
		halo_inner.spawn_weakpoints_at_radius(2, PI * 0.5)


func _enter_phase2_exposed() -> void:
	_set_state(BossState.PHASE2_EXPOSED)
	_exposed_timer = 6.5
	var tween := create_tween()
	tween.tween_property(self, "position:y", _base_position.y + 45.0, 0.5)


func _enter_corruption_core_phase() -> void:
	_set_state(BossState.CORRUPTION_CORE)
	_core_hits = 0
	_attack_timer = 1.8
	if halo_outer != null:
		halo_outer.visible = false
	if halo_inner != null:
		halo_inner.visible = false
	if corruption_core != null:
		corruption_core.visible = true
		corruption_core.scale = Vector2.ONE
		if core_weakpoint != null:
			core_weakpoint.reset_point()


func _enter_final_purification() -> void:
	_set_state(BossState.FINAL_PURIFICATION)
	if blood_rain_controller != null:
		blood_rain_controller.stop_rain()
	if vfx_controller != null:
		vfx_controller.set_weather_heavy(false)
	var tween := create_tween()
	tween.tween_property(self, "position:y", _base_position.y + 50.0, 1.2)


func _on_halo_outer_shattered(_ring: CorruptionRing) -> void:
	if state == BossState.BLOOD_RAIN:
		_enter_phase1_exposed()
	elif state == BossState.FEATHER_STORM:
		if halo_inner == null or halo_inner._broken:
			_enter_phase2_exposed()


func _on_halo_inner_shattered(_ring: CorruptionRing) -> void:
	if state == BossState.FEATHER_STORM:
		if halo_outer == null or halo_outer._broken:
			_enter_phase2_exposed()


func _on_core_weakpoint_purified(_wp: SeraphWeakpoint) -> void:
	_core_hits += 1
	_flash_boss(Color(1.5, 1.5, 2.0, 1.0))
	if _core_hits >= 3:
		# Core destroyed!
		corruption = 1.0
		corruption_changed.emit(corruption, max_corruption)
		_enter_final_purification()
		if corruption_core != null:
			var core_tween := create_tween().set_parallel(true)
			core_tween.tween_property(corruption_core, "scale", Vector2(1.8, 1.8), 0.3)
			core_tween.tween_property(corruption_core, "modulate:a", 0.0, 0.3)
			core_tween.finished.connect(func():
				if is_instance_valid(corruption_core):
					corruption_core.visible = false
			)
	else:
		# Core shrinks and cracks
		if corruption_core != null:
			var next_scale: float = 1.0 - _core_hits * 0.25
			var core_tween := create_tween()
			core_tween.tween_property(corruption_core, "scale", Vector2(next_scale, next_scale), 0.2)
		if core_weakpoint != null:
			core_weakpoint.reset_point()
		corruption = maxf(1.0, 35.0 - _core_hits * 11.0)
		corruption_changed.emit(corruption, max_corruption)


# Potion hit response on Boss Body
func receive_potion_hit(hit: Dictionary) -> void:
	var pid := StringName(str(hit.get("potion_id", "")))
	var potion_obj: PotionData = hit.get("potion") as PotionData
	var main_effect := potion_obj.main_effect_id if potion_obj != null else &""
	if pid == &"purification_potion" or pid == &"purify" or main_effect == &"purify":
		_handle_purification_hit()
	else:
		_handle_non_purify_hit()


func apply_potion_effect(effect_id: StringName, _context: Dictionary = {}) -> void:
	if effect_id == &"purify" or effect_id == &"purification":
		_handle_purification_hit()
	else:
		_handle_non_purify_hit()


func _handle_non_purify_hit() -> void:
	# Subtle non-damaging magic spark
	_flash_boss(Color(0.8, 0.8, 0.8, 0.8), 0.08)


func _handle_purification_hit() -> void:
	match state:
		BossState.PHASE1_EXPOSED:
			corruption = 70.0
			corruption_changed.emit(corruption, max_corruption)
			_flash_boss(Color(0.8, 1.8, 1.6, 1.0))
			_enter_feather_storm_phase()

		BossState.PHASE2_EXPOSED:
			_phase2_hits += 1
			if _phase2_hits == 1:
				corruption = 52.0
				corruption_changed.emit(corruption, max_corruption)
				_flash_boss(Color(0.8, 1.8, 1.6, 1.0))
			else:
				corruption = 35.0
				corruption_changed.emit(corruption, max_corruption)
				_flash_boss(Color(0.8, 1.8, 1.6, 1.0))
				_enter_corruption_core_phase()

		BossState.FINAL_PURIFICATION:
			corruption = 0.0
			corruption_changed.emit(corruption, max_corruption)
			_purify_boss()


func _purify_boss() -> void:
	_set_state(BossState.RESTORED)
	if vfx_controller != null:
		await vfx_controller.play_purification_sequence(global_position)
	boss_purified_completed.emit()


func _flash_boss(col: Color, dur := 0.15) -> void:
	if seraph_corrupted != null:
		var tween := create_tween()
		tween.tween_property(seraph_corrupted, "modulate", col, dur * 0.5)
		tween.tween_property(seraph_corrupted, "modulate", Color.WHITE, dur * 0.5)


func _set_state(new_state: BossState) -> void:
	state = new_state
	boss_state_changed.emit(state)


# --- Feather Attacks (Phase 2) ---

func _trigger_feather_attack() -> void:
	_feather_pattern_index = (_feather_pattern_index + 1) % 3
	match _feather_pattern_index:
		0: _spawn_feather_pattern_fan()
		1: _spawn_feather_pattern_sweep()
		2: _spawn_feather_pattern_homing()


func _spawn_feather_pattern_fan() -> void:
	var count := 5
	var start_angle := PI * 0.3
	var end_angle := PI * 0.7
	for i in range(count):
		var angle := start_angle + float(i) / float(count - 1) * (end_angle - start_angle)
		var dir := Vector2(cos(angle), sin(angle))
		_spawn_feather(global_position + dir * 40.0, dir, 320.0)


func _spawn_feather_pattern_sweep() -> void:
	var sweep_left := randf() > 0.5
	var start_x := 380.0 if sweep_left else 1620.0
	var target_dir := Vector2.RIGHT if sweep_left else Vector2.LEFT
	for i in range(4):
		await get_tree().create_timer(0.2).timeout
		if state != BossState.FEATHER_STORM:
			return
		var spawn_pos := Vector2(start_x, 420.0 + i * 45.0)
		_spawn_feather(spawn_pos, target_dir, 380.0)


func _spawn_feather_pattern_homing() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var target_pos := player.global_position if player != null else Vector2(1000, 600)
	var dir_left := (target_pos - (global_position + Vector2(-60, 0))).normalized()
	var dir_right := (target_pos - (global_position + Vector2(60, 0))).normalized()
	_spawn_feather(global_position + Vector2(-60, 0), dir_left, 260.0, true)
	_spawn_feather(global_position + Vector2(60, 0), dir_right, 260.0, true)


func _spawn_feather(pos: Vector2, dir: Vector2, speed: float, homing := false) -> void:
	var feather := Area2D.new()
	feather.position = pos
	feather.rotation = dir.angle()
	feather.collision_layer = 3 # Can be hit by potions and hit players
	feather.collision_mask = 1

	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(18, 0),
		Vector2(4, -8),
		Vector2(-14, -5),
		Vector2(-20, 0),
		Vector2(-14, 5),
		Vector2(4, 8)
	])
	poly.color = Color(0.25, 0.04, 0.18, 0.95)
	feather.add_child(poly)

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	col.shape = shape
	feather.add_child(col)

	var trail := Line2D.new()
	trail.width = 4.0
	trail.default_color = Color(0.8, 0.1, 0.35, 0.6)
	trail.points = PackedVector2Array([Vector2.ZERO, -dir * 25.0])
	feather.add_child(trail)

	get_parent().add_child(feather)

	feather.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") or body.name == "Player":
			var runtime := _get_day_runtime()
			if runtime != null and runtime.has_method("apply_player_damage"):
				runtime.call("apply_player_damage", damage_feather, StringName("seraph_feather"))
			elif body.has_method("apply_damage"):
				body.call("apply_damage", damage_feather)
			if is_instance_valid(feather):
				feather.queue_free()
	)

	# Movement tween
	var travel_dist := 1200.0
	var travel_time := travel_dist / speed
	var tween := create_tween()
	var dest := pos + dir * travel_dist
	tween.tween_property(feather, "position", dest, travel_time)
	tween.finished.connect(func():
		if is_instance_valid(feather):
			feather.queue_free()
	)


# --- Shockwave Attack (Phase 3) ---

func _trigger_shockwave_attack() -> void:
	var center := Vector2(global_position.x, 600.0) # floor level wave
	var wave := Area2D.new()
	wave.position = center
	wave.collision_layer = 0
	wave.collision_mask = 1

	var line := Line2D.new()
	line.width = 16.0
	line.default_color = Color(0.85, 0.1, 0.3, 0.9)
	var pts := PackedVector2Array()
	var segs := 36
	for i in range(segs + 1):
		var a := float(i) / float(segs) * TAU
		pts.append(Vector2(cos(a), sin(a)) * 10.0)
	line.points = pts
	wave.add_child(line)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	wave.add_child(col)

	get_parent().add_child(wave)

	wave.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") or body.name == "Player":
			# If player is on high platform (Y < 510), they jump over the shockwave
			if body.global_position.y > 520.0:
				var runtime := _get_day_runtime()
				if runtime != null and runtime.has_method("apply_player_damage"):
					runtime.call("apply_player_damage", damage_shockwave, StringName("corruption_shockwave"))
				elif body.has_method("apply_damage"):
					body.call("apply_damage", damage_shockwave)
	)

	# Expand wave outwards
	var tween := create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector2(45.0, 18.0), 1.3)
	tween.tween_property(line, "modulate:a", 0.0, 1.3)
	await tween.finished
	if is_instance_valid(wave):
		wave.queue_free()


func _on_body_entered_boss(body: Node2D) -> void:
	if body.is_in_group("player") and state != BossState.RESTORED and state != BossState.FINAL_PURIFICATION:
		var runtime := _get_day_runtime()
		if runtime != null and runtime.has_method("apply_player_damage"):
			runtime.call("apply_player_damage", 10, StringName("seraph_body"))


func _get_day_runtime() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.has_method("apply_player_damage") or cursor.has_method("switch_to_level"):
			return cursor
		cursor = cursor.get_parent()
	return null
