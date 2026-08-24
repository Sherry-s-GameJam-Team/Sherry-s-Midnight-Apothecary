class_name BossDreamGraspTracker
extends Node2D

## Auto-homing Dream Grasp Hands tracker for Vesper Director Boss battle.
## Spawns the authentic inner DreamGraspHandUnit on ground.
## Player can evade tracking by standing on Platform1.

const HAND_UNIT_SCENE := preload("res://day/levels/Vespervale/inner_systems/dream_grasp_hand_unit.tscn")

@export var track_duration: float = 1.4
@export var lock_duration: float = 0.5
@export var follow_speed: float = 4.8
@export var ground_y: float = 610.0
@export var min_x: float = 80.0
@export var max_x: float = 1840.0
@export var damage: int = 30
@export var cluster_count: int = 1

enum State { TRACK, LOCK, ERUPT, COMPLETED }

var current_state: State = State.TRACK
var is_sheltered_on_platform1: bool = false
var _state_timer: float = 0.0
var _current_x: float = 960.0
var _target_player: Node2D = null
var _platform1: Node2D = null
var _is_cancelled: bool = false

@onready var shadow_visual: Polygon2D = get_node_or_null("ShadowVisual")
@onready var telegraph_ring: Node2D = get_node_or_null("TelegraphRing")


func setup(player: Node2D, start_x: float = -1.0, p_cluster_count: int = 1, p_damage: int = 15) -> void:
	_target_player = player if player != null else _find_player()
	cluster_count = p_cluster_count
	damage = p_damage

	var init_x := start_x
	if init_x < 0.0 or _target_player != null:
		var p := _find_player()
		if p != null:
			init_x = p.global_position.x

	_current_x = clampf(init_x if init_x >= 0.0 else 960.0, min_x, max_x)
	global_position = Vector2(_current_x, ground_y)


func _ready() -> void:
	_discover_platform1()
	if _target_player == null:
		_target_player = _find_player()
	_transition_to(State.TRACK)


func _discover_platform1() -> void:
	if is_inside_tree() and get_tree() != null:
		var root := get_tree().current_scene
		if root != null:
			_platform1 = root.find_child("Platform1", true, false) as Node2D


func _find_player() -> Node2D:
	if _target_player != null and is_instance_valid(_target_player):
		return _target_player
	if is_inside_tree() and get_tree() != null:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p != null:
			_target_player = p
			return _target_player
		var root := get_tree().current_scene
		if root != null:
			_target_player = root.find_child("Player", true, false) as Node2D
			return _target_player
	return null


func is_target_on_platform1() -> bool:
	var player := _find_player()
	if player == null or not is_instance_valid(player):
		return false

	var px: float = player.global_position.x
	var py: float = player.global_position.y

	# Platform1 in vesper_boss.tscn is at (428, 542), scaled width ~725 (X span ~65..790), surface Y ~530
	# When player is on Platform1 (elevated above ground floor Y=610):
	if px >= 60.0 and px <= 800.0 and py <= 555.0:
		return true

	if _platform1 != null and is_instance_valid(_platform1):
		var plat_pos := _platform1.global_position
		if absf(px - plat_pos.x) <= 380.0 and py <= plat_pos.y + 15.0 and py >= plat_pos.y - 120.0:
			return true

	return false


func _process(delta: float) -> void:
	if _is_cancelled or current_state == State.COMPLETED:
		return

	is_sheltered_on_platform1 = is_target_on_platform1()
	var player := _find_player()

	_state_timer -= delta

	match current_state:
		State.TRACK:
			if not is_sheltered_on_platform1 and player != null and is_instance_valid(player):
				var target_x := clampf(player.global_position.x, min_x, max_x)
				var weight := clampf(follow_speed * delta, 0.0, 1.0)
				_current_x = lerpf(_current_x, target_x, weight)
				global_position = Vector2(_current_x, ground_y)
				if shadow_visual != null:
					shadow_visual.modulate.a = 0.85
			else:
				# Target is on Platform1 or sheltered - tracking lost/evaded!
				if shadow_visual != null:
					shadow_visual.modulate.a = 0.35

			if _state_timer <= 0.0:
				_transition_to(State.LOCK)

		State.LOCK:
			# Position is frozen at locked spot
			if _state_timer <= 0.0:
				_transition_to(State.ERUPT)

		State.ERUPT:
			pass


func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.TRACK:
			_state_timer = track_duration
			if telegraph_ring != null:
				telegraph_ring.visible = false
			if shadow_visual != null:
				shadow_visual.visible = true

		State.LOCK:
			_state_timer = lock_duration
			if telegraph_ring != null:
				telegraph_ring.visible = true
				telegraph_ring.modulate.a = 0.0
				var tw := create_tween()
				if tw != null:
					tw.tween_property(telegraph_ring, "modulate:a", 1.0, lock_duration * 0.5)

		State.ERUPT:
			_erupt_hand_units()


func _erupt_hand_units() -> void:
	current_state = State.COMPLETED
	if shadow_visual != null:
		shadow_visual.visible = false
	if telegraph_ring != null:
		telegraph_ring.visible = false

	var container := get_parent()
	if container == null:
		container = self

	var count := maxi(cluster_count, 1)
	for i in range(count):
		var offset_x := (i - (count - 1) * 0.5) * 80.0
		var spawn_pos := Vector2(_current_x + offset_x, ground_y)
		var hand_unit: DreamGraspHandUnit = HAND_UNIT_SCENE.instantiate() as DreamGraspHandUnit
		if hand_unit != null:
			hand_unit.damage = damage
			hand_unit.global_position = spawn_pos
			container.add_child(hand_unit)
			hand_unit.start_lock_and_erupt(0.1)

	queue_free()


func cancel_and_dissipate() -> void:
	_is_cancelled = true
	var tw := create_tween()
	if tw != null:
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
	else:
		queue_free()
