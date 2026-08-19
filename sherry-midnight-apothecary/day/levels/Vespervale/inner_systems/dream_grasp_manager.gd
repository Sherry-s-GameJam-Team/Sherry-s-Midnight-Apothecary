class_name DreamGraspManager
extends Node2D

## Dream Grasp Hands (幽眠攫手) Central Manager.
## Implements the 5-state dream hunting mechanic for Vespervale Corridor:
## LURK -> TRACK -> LOCK -> ERUPT -> RETRACT
##
## Features:
## - Full fairness: tracking shadow locks in place before eruption so player can read and dodge.
## - Bed safe zone immunity & threat tier escalation (Tier 1: 0-8s, Tier 2: 8-16s, Tier 3: >16s).
## - Dual-character switch awareness (tracks active character, locked attacks stay on old spot).
## - Dream/Reality state synchronicity (active only in Dream State).
## - Dynamic floor/platform raycasting for both upper and lower levels.

signal state_changed(new_state: State)
signal hunt_tier_changed(new_tier: int)

enum State { LURK, TRACK, LOCK, ERUPT, RETRACT }

const HAND_UNIT_SCENE := preload("res://day/levels/Vespervale/inner_systems/dream_grasp_hand_unit.tscn")

@export var track_duration: float = 1.5
@export var lock_duration: float = 0.5
@export var retract_cooldown: float = 0.7
@export var upper_track_y: float = 320.0
@export var lower_track_y: float = 600.0

var current_state: State = State.LURK
var hunt_time: float = 0.0 # Time continuously outside bed safe zone
var hunt_tier: int = 1

var _state_timer: float = 0.0
var _locked_position: Vector2 = Vector2.ZERO
var _tracking_position: Vector2 = Vector2.ZERO
var _active_units: Array[DreamGraspHandUnit] = []
var _safe_zones: Array[DreamBedSafeZone] = []

@onready var tracking_shadow: Node2D = get_node_or_null("TrackingShadow")
@onready var ground_ray: RayCast2D = get_node_or_null("GroundRay")

var _party_controller: InnerPartyController
var _shift_manager: DreamShiftManager
var _audio_synth: DreamAudioSynth


func _ready() -> void:
	_init_system_references()
	_discover_safe_zones()
	_update_tracking_shadow_visual(false)


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
		return

	var active_char := _get_active_body()
	if active_char == null:
		return

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

	# State machine execution
	_state_timer -= delta
	match current_state:
		State.LURK:
			_update_tracking_shadow_visual(false)
			if not is_sheltered and _is_in_dream():
				_transition_to(State.TRACK)

		State.TRACK:
			_update_tracking_position(active_char)
			_update_tracking_shadow_visual(true)
			if _state_timer <= 0.0:
				_transition_to(State.LOCK)

		State.LOCK:
			# Position is FROZEN; shadow stops moving and ripples
			if _state_timer <= 0.0:
				_transition_to(State.ERUPT)

		State.ERUPT:
			if _state_timer <= 0.0:
				_transition_to(State.RETRACT)

		State.RETRACT:
			_update_tracking_shadow_visual(false)
			if _state_timer <= 0.0:
				if is_sheltered:
					_transition_to(State.LURK)
				else:
					_transition_to(State.TRACK)


func _transition_to(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(current_state)

	match current_state:
		State.LURK:
			_state_timer = 0.5
			_update_tracking_shadow_visual(false)

		State.TRACK:
			_state_timer = track_duration
			var active_char := _get_active_body()
			if active_char != null:
				_update_tracking_position(active_char)
			_update_tracking_shadow_visual(true)

		State.LOCK:
			_state_timer = lock_duration
			_locked_position = _tracking_position
			_play_lock_cue()

		State.ERUPT:
			_state_timer = 0.45
			_spawn_eruption_wave(_locked_position, hunt_tier)

		State.RETRACT:
			_state_timer = retract_cooldown


func _update_tracking_position(body: Node2D) -> void:
	var target_x := body.global_position.x
	var floor_y := _find_floor_y(body)
	_tracking_position = Vector2(target_x, floor_y)
	if tracking_shadow != null:
		tracking_shadow.global_position = _tracking_position


func _find_floor_y(body: Node2D) -> float:
	# Raycast downward from character to find actual standing surface
	if ground_ray != null:
		ground_ray.global_position = Vector2(body.global_position.x, body.global_position.y - 20.0)
		ground_ray.force_raycast_update()
		if ground_ray.is_colliding():
			return ground_ray.get_collision_point().y

	# Fallback heuristic: upper observation corridor (y < 420) vs lower ground (y >= 420)
	return upper_track_y if body.global_position.y < 420.0 else lower_track_y


func _play_lock_cue() -> void:
	if _audio_synth != null and _audio_synth.has_method("play_lock_bell"):
		_audio_synth.call("play_lock_bell")

	# Lock ripple animation on tracking shadow
	if tracking_shadow != null:
		var tw := create_tween()
		tw.tween_property(tracking_shadow, "scale", Vector2(1.3, 0.7), 0.15)
		tw.tween_property(tracking_shadow, "scale", Vector2(1.0, 0.5), 0.15)


func _spawn_eruption_wave(pos: Vector2, tier: int) -> void:
	# 1. Main grasp point
	_spawn_single_hand_unit(pos, false)

	# 2. Tier 2 & 3: Side companion grasp points
	if tier >= 2:
		_spawn_single_hand_unit(pos + Vector2(-75.0, 0.0), true)
		_spawn_single_hand_unit(pos + Vector2(75.0, 0.0), true)

	# 3. Tier 3: Follow-up rapid second wave after 0.55s
	if tier >= 3 and is_inside_tree() and get_tree() != null:
		get_tree().create_timer(0.55).timeout.connect(func() -> void:
			if _is_in_dream() and not _is_body_sheltered(_get_active_body()):
				var active_char := _get_active_body()
				if active_char != null:
					var follow_up_pos := Vector2(active_char.global_position.x, _find_floor_y(active_char))
					_spawn_single_hand_unit(follow_up_pos, false)
		)


func _spawn_single_hand_unit(global_pos: Vector2, secondary: bool) -> void:
	var unit := HAND_UNIT_SCENE.instantiate() as DreamGraspHandUnit
	unit.global_position = global_pos
	unit.is_secondary = secondary
	add_child(unit)
	_active_units.append(unit)
	unit.start_lock_and_erupt(0.1 if current_state == State.ERUPT else lock_duration)
	unit.unit_completed.connect(func() -> void:
		_active_units.erase(unit)
	)


func _update_tracking_shadow_visual(is_active: bool) -> void:
	if tracking_shadow != null:
		tracking_shadow.visible = is_active
		tracking_shadow.modulate.a = 0.7 if is_active else 0.0


func _set_hunt_tier(tier: int) -> void:
	if hunt_tier != tier:
		hunt_tier = tier
		hunt_tier_changed.emit(hunt_tier)


func _on_active_character_changed(_character_id: StringName) -> void:
	# If currently tracking, smoothly update to follow new active character
	if current_state == State.TRACK:
		var active_char := _get_active_body()
		if active_char != null:
			_update_tracking_position(active_char)


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
