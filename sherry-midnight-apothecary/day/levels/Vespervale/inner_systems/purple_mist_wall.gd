class_name PurpleMistWall
extends Area2D

## Zone 4 pursuit obstacle: A towering wall of dream mist that creeps forward during Dream state.
## Deals periodic damage on contact to encourage steady forward platforming.

@export var advance_speed: float = 65.0
@export var retreat_speed: float = 40.0
@export var min_x: float = 2800.0
@export var max_x: float = 3800.0
@export var damage_tick_interval: float = 1.0

var _is_dream: bool = false
var _damage_timer: float = 0.0
var _pulse_phase: float = 0.0
var _overlapping_players: Array[Node2D] = []


func _ready() -> void:
	add_to_group("hazard")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var manager := _find_shift_manager()
	if manager != null:
		manager.dream_state_changed.connect(_on_dream_state_changed)
		_is_dream = manager.is_in_dream()


func _physics_process(delta: float) -> void:
	_pulse_phase += delta * 3.0
	queue_redraw()

	if _is_dream:
		position.x = minf(position.x + advance_speed * delta, max_x)
	else:
		position.x = maxf(position.x - retreat_speed * delta, min_x)

	if not _overlapping_players.is_empty():
		_damage_timer -= delta
		if _damage_timer <= 0.0:
			_damage_timer = damage_tick_interval
			_apply_mist_damage()


func _draw() -> void:
	var h := 900.0
	var w := 200.0
	var alpha := 0.75 if _is_dream else 0.35
	var col_deep := Color(0.45, 0.1, 0.6, alpha)
	var col_front := Color(0.7, 0.25, 0.9, alpha * 0.7)
	# Gradient mist rect
	draw_rect(Rect2(-w, -h * 0.5, w, h), col_deep, true)
	# Wavy front edge
	for i in range(12):
		var y := -h * 0.5 + float(i) * 75.0
		var offset_x := sin(_pulse_phase + float(i) * 0.8) * 20.0
		draw_circle(Vector2(offset_x, y), 50.0, col_front)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.is_in_group("player") or body.name == "Player"):
		if not _overlapping_players.has(body):
			_overlapping_players.append(body)
		_apply_mist_damage()


func _on_body_exited(body: Node2D) -> void:
	_overlapping_players.erase(body)


func _apply_mist_damage() -> void:
	var env := _find_environment()
	if env != null and env.has_method("apply_player_damage"):
		env.call("apply_player_damage", 1, &"purple_mist_wall")
	else:
		for p in _overlapping_players:
			if p.has_method("take_damage"):
				p.call("take_damage", 1)


func _on_dream_state_changed(in_dream: bool) -> void:
	_is_dream = in_dream


func _find_shift_manager() -> DreamShiftManager:
	var cur: Node = self
	while cur != null:
		var mgr := cur.get_node_or_null("DreamShiftManager") as DreamShiftManager
		if mgr != null:
			return mgr
		cur = cur.get_parent()
	return null


func _find_environment() -> Node:
	var cur: Node = self
	while cur != null:
		if cur is DayLevelEnvironment:
			return cur
		cur = cur.get_parent()
	return null
