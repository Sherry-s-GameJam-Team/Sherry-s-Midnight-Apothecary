class_name DreamGraspManager
extends Node2D

## Dream Grasp Hands (幽眠攫手) Central Manager.
## Implements the 5-state dream hunting mechanic for Vespervale Corridor:
## LURK -> TRACK -> LOCK -> ERUPT -> RETRACT
##
## Behavior:
## - Enemy Y-axis is locked strictly to the 1st floor ground surface (ground_floor_y = 600.0).
## - Smooth lerp movement: shadow glides smoothly towards the target character's X position.
## - Continuous breathing animation: visible purple dream pulse present on the 1st floor ground.
## - Bed safe zone immunity & threat tier escalation (Tier 1: 0-8s, Tier 2: 8-16s, Tier 3: >16s).
## - Dual-character switch awareness (tracks active character, locked attacks stay on old spot).
## - Dream/Reality state synchronicity (active only in Dream State).

signal state_changed(new_state: State)
signal hunt_tier_changed(new_tier: int)

enum State { LURK, TRACK, LOCK, ERUPT, RETRACT }

const HAND_UNIT_SCENE := preload("res://day/levels/Vespervale/inner_systems/dream_grasp_hand_unit.tscn")

@export var track_duration: float = 1.5
@export var lock_duration: float = 0.5
@export var retract_cooldown: float = 0.7
@export var ground_floor_y: float = 600.0
@export var smooth_follow_speed: float = 3.6
@export var breathing_speed: float = 2.5

var current_state: State = State.LURK
var hunt_time: float = 0.0 # Time continuously outside bed safe zone
var hunt_tier: int = 1

var _state_timer: float = 0.0
var _current_x: float = 600.0
var _locked_position: Vector2 = Vector2.ZERO
var _tracking_position: Vector2 = Vector2.ZERO
var _breathing_phase: float = 0.0
var _active_units: Array[DreamGraspHandUnit] = []
var _safe_zones: Array[DreamBedSafeZone] = []

@onready var tracking_shadow: Node2D = get_node_or_null("TrackingShadow")

var _party_controller: InnerPartyController
var _shift_manager: DreamShiftManager
var _audio_synth: DreamAudioSynth


func _ready() -> void:
	_init_system_references()
	_discover_safe_zones()
	var active_char := _get_active_body()
	if active_char != null:
		_current_x = active_char.global_position.x
	_tracking_position = Vector2(_current_x, ground_floor_y)
	if tracking_shadow != null:
		tracking_shadow.global_position = _tracking_position


func _init_system_references() -> void:
	var cur: Node = self
	while cur != null:
		if _party_controller == null:
			_party_controller = cur.get_node_or_null("InnerPartyController") as InnerPartyController
		if _shift_manager == null:
			_shift_manager = cur.get_node_or_null("DreamShiftManager") as DreamShiftManager
		if _audio_synth == null:
			_audio_synth = cur.get_node_or_null("DreamShiftManager/DreamAudioSynth") as DreamAudioSynth
		cur = cur.get_parent()

	if _shift_manager != null:
		_shift_manager.dream_state_changed.connect(_on_dream_state_changed)
	if _party_controller != null:
		_party_controller.active_character_changed.connect(_on_active_character_changed)


func _discover_safe_zones() -> void:
	_safe_zones.clear()
	for node: Node in get_tree().get_nodes_in_group("bed_safe_zone"):
		if node is DreamBedSafeZone:
			_safe_zones.append(node)


func _process(delta: float) -> void:
	if not _is_in_dream():
		if current_state != State.LURK:
			_transition_to(State.LURK)
		if tracking_shadow != null:
			tracking_shadow.visible = false
		return

	var active_char := _get_active_body()
	if active_char == null:
		return

	# Update breathing animation
	_breathing_phase += delta * breathing_speed
	var breath := (sin(_breathing_phase) + 1.0) * 0.5
	_update_breathing_visual(breath)

	var is_sheltered := _is_body_sheltered(active_char)

	if is_sheltered:
		# Reset hunt timer in bed sanctuary
		if hunt_time > 0.0:
			hunt_time = 0.0
			_set_hunt_tier(1)
		if current_state == State.TRACK or current_state == State.LOCK:
			_transition_to(State.LURK)
	else:
		# Outside bed: accumulate hunt time and update threat tier
		hunt_time += delta
		if hunt_time >= 16.0:
			_set_hunt_tier(3)
		elif hunt_time >= 8.0:
			_set_hunt_tier(2)
		else:
			_set_hunt_tier(1)

	# State machine execution & smooth movement
	_state_timer -= delta
	match current_state:
		State.LURK:
			_smooth_follow_target(active_char.global_position.x, delta * 0.6)
			if not is_sheltered and _is_in_dream():
				_transition_to(State.TRACK)

		State.TRACK:
			_smooth_follow_target(active_char.global_position.x, delta)
			if _state_timer <= 0.0:
				_transition_to(State.LOCK)

		State.LOCK:
			# Position is FROZEN at _locked_position
			if _state_timer <= 0.0:
				_transition_to(State.ERUPT)

		State.ERUPT:
			if _state_timer <= 0.0:
				_transition_to(State.RETRACT)

		State.RETRACT:
			_smooth_follow_target(active_char.global_position.x, delta * 0.5)
			if _state_timer <= 0.0:
				if is_sheltered:
					_transition_to(State.LURK)
				else:
					_transition_to(State.TRACK)


func _smooth_follow_target(target_x: float, delta: float) -> void:
	var follow_weight := clampf(smooth_follow_speed * delta, 0.0, 1.0)
	_current_x = lerpf(_current_x, target_x, follow_weight)
	_tracking_position = Vector2(_current_x, ground_floor_y)
	if tracking_shadow != null:
		tracking_shadow.global_position = _tracking_position


func _update_breathing_visual(breath: float) -> void:
	if tracking_shadow == null:
		return

	tracking_shadow.visible = true
	match current_state:
		State.LURK:
			tracking_shadow.modulate.a = lerpf(0.20, 0.45, breath)
			tracking_shadow.scale = Vector2(lerpf(0.88, 1.08, breath), lerpf(0.45, 0.60, breath))
		State.TRACK:
			tracking_shadow.modulate.a = lerpf(0.55, 0.90, breath)
			tracking_shadow.scale = Vector2(lerpf(1.00, 1.30, breath), lerpf(0.52, 0.76, breath))
		State.LOCK:
			tracking_shadow.modulate.a = 0.95
			# Lock pulse is handled by tween in _play_lock_cue
		State.ERUPT:
			tracking_shadow.modulate.a = 0.4
		State.RETRACT:
			tracking_shadow.modulate.a = lerpf(0.15, 0.35, breath)


func _transition_to(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(current_state)

	match current_state:
		State.LURK:
			_state_timer = 0.5

		State.TRACK:
			_state_timer = track_duration

		State.LOCK:
			_state_timer = lock_duration
			_locked_position = Vector2(_current_x, ground_floor_y)
			_play_lock_cue()

		State.ERUPT:
			_state_timer = 0.45
			_spawn_eruption_wave(_locked_position, hunt_tier)

		State.RETRACT:
			_state_timer = retract_cooldown


func _play_lock_cue() -> void:
	if _audio_synth != null and _audio_synth.has_method("play_lock_bell"):
		_audio_synth.call("play_lock_bell")

	# Lock ripple animation on tracking shadow
	if tracking_shadow != null:
		var tw := create_tween()
		if tw != null:
			tw.tween_property(tracking_shadow, "scale", Vector2(1.35, 0.8), 0.15)
			tw.tween_property(tracking_shadow, "scale", Vector2(1.0, 0.5), 0.15)


func _spawn_eruption_wave(pos: Vector2, tier: int) -> void:
	# Y is locked strictly to 1st floor
	var base_pos := Vector2(pos.x, ground_floor_y)

	# 1. Main grasp point
	_spawn_single_hand_unit(base_pos, false)

	# 2. Tier 2 & 3: Side companion grasp points
	if tier >= 2:
		_spawn_single_hand_unit(base_pos + Vector2(-75.0, 0.0), true)
		_spawn_single_hand_unit(base_pos + Vector2(75.0, 0.0), true)

	# 3. Tier 3: Follow-up rapid second wave after 0.55s
	if tier >= 3 and is_inside_tree() and get_tree() != null:
		get_tree().create_timer(0.55).timeout.connect(func() -> void:
			if _is_in_dream() and not _is_body_sheltered(_get_active_body()):
				var active_char := _get_active_body()
				if active_char != null:
					var follow_up_pos := Vector2(active_char.global_position.x, ground_floor_y)
					_spawn_single_hand_unit(follow_up_pos, false)
		)


func _spawn_single_hand_unit(global_pos: Vector2, secondary: bool) -> void:
	var unit := HAND_UNIT_SCENE.instantiate() as DreamGraspHandUnit
	unit.global_position = Vector2(global_pos.x, ground_floor_y)
	unit.is_secondary = secondary
	add_child(unit)
	_active_units.append(unit)
	unit.start_lock_and_erupt(0.1 if current_state == State.ERUPT else lock_duration)
	unit.unit_completed.connect(func() -> void:
		_active_units.erase(unit)
	)


func _set_hunt_tier(tier: int) -> void:
	if hunt_tier != tier:
		hunt_tier = tier
		hunt_tier_changed.emit(hunt_tier)


func _on_active_character_changed(_character_id: StringName) -> void:
	pass


func _on_dream_state_changed(in_dream: bool) -> void:
	if not in_dream:
		# Reality Intrusion: immediately dissipate all active hand units
		for unit in _active_units:
			if is_instance_valid(unit):
				unit.cancel_and_dissipate()
		_active_units.clear()
		_transition_to(State.LURK)
	else:
		_transition_to(State.LURK)


func _is_in_dream() -> bool:
	if _shift_manager != null and _shift_manager.has_method("is_in_dream"):
		return _shift_manager.call("is_in_dream")
	return true


func _get_active_body() -> Node2D:
	if _party_controller != null and _party_controller.has_method("active_body"):
		return _party_controller.call("active_body")
	return get_node_or_null("../Player") as Node2D


func _is_body_sheltered(body: Node2D) -> bool:
	if body == null:
		return false
	for zone in _safe_zones:
		if is_instance_valid(zone) and zone.is_body_sheltered(body):
			return true
	return false
