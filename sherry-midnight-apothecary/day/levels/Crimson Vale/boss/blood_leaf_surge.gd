class_name BloodLeafSurge
extends Area2D

signal surge_started
signal surge_cleared_by_wind
signal surge_finished

enum SurgeType {
	HORIZONTAL_SWEEP,
	DOWNWARD_CRUSH,
	CONVERGING_SWARM
}

enum State {
	IDLE,
	TELEGRAPH,
	ACTIVE,
	HEADWIND_SAFE,
	DISSIPATING
}

@export var surge_type: SurgeType = SurgeType.HORIZONTAL_SWEEP
@export var zone_index: int = 0
@export var zone_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(550, 480))
@export var sweep_direction: float = 1.0 # 1.0 = left-to-right, -1.0 = right-to-left
@export var telegraph_duration: float = 1.5
@export var active_duration: float = 2.2
@export var headwind_duration: float = 1.8
@export var surge_speed: float = 300.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var telegraph_indicator: Node2D = $TelegraphIndicator
@onready var particle_layer: GPUParticles2D = $Particles
@onready var headwind_particles: GPUParticles2D = $HeadwindParticles

var current_state: State = State.IDLE
var _state_timer: float = 0.0
var _hit_targets: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = false
	monitorable = false
	add_to_group("blood_leaf_surge")
	add_to_group("potion_target")

	body_entered.connect(_on_body_entered)
	_update_zone_bounds()
	_set_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if current_state == State.IDLE:
		return

	_state_timer -= delta

	match current_state:
		State.TELEGRAPH:
			_process_telegraph(delta)
			if _state_timer <= 0.0:
				_enter_active_state()
		State.ACTIVE:
			_process_active_surge(delta)
			if _state_timer <= 0.0:
				_enter_dissipating_state()
		State.HEADWIND_SAFE:
			if _state_timer <= 0.0:
				_enter_dissipating_state()
		State.DISSIPATING:
			if _state_timer <= 0.0:
				_set_state(State.IDLE)
				surge_finished.emit()


func start_telegraph(duration: float = 1.5, type: SurgeType = SurgeType.HORIZONTAL_SWEEP, dir: float = 1.0) -> void:
	surge_type = type
	sweep_direction = dir
	telegraph_duration = duration
	_set_state(State.TELEGRAPH)
	_state_timer = telegraph_duration
	_update_zone_bounds()


func delay_attack(extra_seconds: float = 1.0) -> void:
	if current_state == State.TELEGRAPH:
		_state_timer += extra_seconds


func make_headwind_safe(duration: float = 1.8) -> void:
	if current_state == State.TELEGRAPH or current_state == State.ACTIVE:
		headwind_duration = duration
		_set_state(State.HEADWIND_SAFE)
		_state_timer = headwind_duration
		surge_cleared_by_wind.emit()


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: StringName = hit.get("potion_id", &"")
	var effect_id: StringName = hit.get("main_effect_id", &"")
	var pid_str := String(potion_id).to_lower()
	var eid_str := String(effect_id).to_lower()
	if pid_str.contains("wind") or pid_str.contains("cyan") or pid_str.contains("purification") or pid_str.contains("pure") or eid_str.contains("wind") or eid_str.contains("purification"):
		make_headwind_safe(2.0)


func apply_potion_effect(effect_id: StringName, _context: Dictionary = {}) -> void:
	var eid_str := String(effect_id).to_lower()
	if eid_str.contains("wind") or eid_str.contains("cyan") or eid_str.contains("purification") or eid_str.contains("pure") or eid_str.contains("gust"):
		make_headwind_safe(2.0)


func _enter_active_state() -> void:
	_set_state(State.ACTIVE)
	_state_timer = active_duration
	_hit_targets.clear()
	monitoring = true
	surge_started.emit()


func _enter_dissipating_state() -> void:
	_set_state(State.DISSIPATING)
	_state_timer = 0.5
	monitoring = false


func _set_state(new_state: State) -> void:
	current_state = new_state

	if telegraph_indicator != null:
		telegraph_indicator.visible = (new_state == State.TELEGRAPH)
	if particle_layer != null:
		particle_layer.emitting = (new_state == State.ACTIVE or new_state == State.TELEGRAPH)
		if new_state == State.HEADWIND_SAFE:
			particle_layer.emitting = false
	if headwind_particles != null:
		headwind_particles.emitting = (new_state == State.HEADWIND_SAFE)


func _process_telegraph(_delta: float) -> void:
	if telegraph_indicator != null:
		var alpha := 0.4 + sin(Time.get_ticks_msec() * 0.01) * 0.3
		telegraph_indicator.modulate = Color(1.0, 0.3, 0.3, alpha)


func _process_active_surge(_delta: float) -> void:
	# Check bodies in zone
	for body in get_overlapping_bodies():
		_deal_surge_damage(body)


func _on_body_entered(body: Node2D) -> void:
	if current_state == State.ACTIVE:
		_deal_surge_damage(body)


func _deal_surge_damage(body: Node2D) -> void:
	if not monitoring or current_state != State.ACTIVE:
		return

	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		# Ignore if player is in shelter or invulnerable
		if body.get_meta("sheltered", false) or body.is_in_group("sheltered"):
			return

		var id := body.get_instance_id()
		var now := float(Time.get_ticks_msec()) / 1000.0
		if _hit_targets.has(id) and now - _hit_targets[id] < 1.0:
			return
		_hit_targets[id] = now

		# Apply damage via DayLevelEnvironment
		var env := _find_environment()
		if env != null:
			env.apply_player_damage(1, &"blood_leaf_surge")


func _find_environment() -> DayLevelEnvironment:
	var cur: Node = self
	while cur != null:
		if cur is DayLevelEnvironment:
			return cur as DayLevelEnvironment
		cur = cur.get_parent()
	return null


func _update_zone_bounds() -> void:
	if collision_shape == null:
		return

	var rect_shape := collision_shape.shape as RectangleShape2D
	if rect_shape == null:
		rect_shape = RectangleShape2D.new()
		collision_shape.shape = rect_shape

	rect_shape.size = zone_rect.size
	collision_shape.position = zone_rect.position + zone_rect.size * 0.5
