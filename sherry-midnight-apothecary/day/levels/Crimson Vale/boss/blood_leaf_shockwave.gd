class_name BloodLeafShockwave
extends Area2D

## Phase 2 Hazard: Sweeping horizontal blood leaf shockwave on fixed vertical layers (Upper/Middle/Lower).

signal shockwave_finished

@export var layer_y: float = 480.0 # Upper: 180, Middle: 330, Lower: 480
@export var sweep_direction: float = 1.0 # 1.0 = Left to Right, -1.0 = Right to Left
@export var sweep_speed: float = 1100.0
@export var damage_per_tick: float = 1.0
@export var tick_interval: float = 0.35

@onready var telegraph_beam: Line2D = $TelegraphBeam
@onready var telegraph_particles: GPUParticles2D = $TelegraphParticles
@onready var wave_particles: GPUParticles2D = $WaveParticles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

enum State { TELEGRAPH, SWEEPING, FINISHED }
var current_state: State = State.TELEGRAPH
var _state_time: float = 0.0
var _telegraph_duration: float = 1.0
var _damage_timer: float = 0.0
var _current_x: float = 0.0


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("blood_leaf_shockwave")
	add_to_group("potion_target")
	collision_layer = 1 | 2
	collision_mask = 1
	monitoring = false
	position.y = layer_y

	if telegraph_beam != null:
		telegraph_beam.visible = false
	if wave_particles != null:
		wave_particles.emitting = false


func start_shockwave(target_layer_y: float, direction: float = 1.0, telegraph_time: float = 1.0) -> void:
	layer_y = target_layer_y
	position.y = layer_y
	sweep_direction = direction
	_telegraph_duration = telegraph_time
	_state_time = 0.0
	current_state = State.TELEGRAPH

	# Initial X position based on direction
	_current_x = -150.0 if sweep_direction > 0.0 else 1850.0
	position.x = _current_x

	# Setup warning beam
	if telegraph_beam != null:
		telegraph_beam.visible = true
		telegraph_beam.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(telegraph_beam, "modulate:a", 0.85, 0.3)
		tw.tween_property(telegraph_beam, "modulate:a", 0.4, 0.25)
		tw.tween_property(telegraph_beam, "modulate:a", 1.0, 0.25)

	if telegraph_particles != null:
		telegraph_particles.emitting = true


func _physics_process(delta: float) -> void:
	_state_time += delta

	match current_state:
		State.TELEGRAPH:
			if _state_time >= _telegraph_duration:
				_enter_sweeping_state()
		State.SWEEPING:
			_process_sweeping(delta)


func _enter_sweeping_state() -> void:
	current_state = State.SWEEPING
	_state_time = 0.0
	monitoring = true

	if telegraph_beam != null:
		telegraph_beam.visible = false
	if telegraph_particles != null:
		telegraph_particles.emitting = false
	if wave_particles != null:
		wave_particles.emitting = true


func _process_sweeping(delta: float) -> void:
	# Advance shockwave across screen
	_current_x += sweep_direction * sweep_speed * delta
	position.x = _current_x

	# Continuous damage tick to overlapping player
	_damage_timer -= delta
	if _damage_timer <= 0.0:
		_damage_timer = tick_interval
		_check_and_damage_players()

	# Check screen exit bounds
	if (sweep_direction > 0.0 and _current_x > 1950.0) or (sweep_direction < 0.0 and _current_x < -250.0):
		_finish_and_cleanup()


func _check_and_damage_players() -> void:
	for body in get_overlapping_bodies():
		if body is CharacterBody2D and (body.is_in_group("player") or body.name == "Player"):
			var knockback := Vector2(sweep_direction * 220.0, -90.0)
			if body.has_method("receive_hit"):
				body.call("receive_hit", damage_per_tick, knockback)
			elif body.has_method("play_hazard_hit"):
				body.call("play_hazard_hit", knockback)


func _finish_and_cleanup() -> void:
	current_state = State.FINISHED
	monitoring = false
	if wave_particles != null:
		wave_particles.emitting = false
	shockwave_finished.emit()
	queue_free()


func dispel() -> void:
	# Dispel shockwave with wind or purification
	monitoring = false
	if wave_particles != null:
		wave_particles.emitting = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: StringName = hit.get("potion_id", &"")
	var pid_str := String(potion_id).to_lower()
	if pid_str.contains("wind") or pid_str.contains("cyan") or pid_str.contains("purif") or pid_str.contains("pure"):
		dispel()
