class_name LakeElevator
extends AnimatableBody2D

signal state_changed(state: State)
signal travel_started(descending: bool)
signal travel_finished(at_bottom: bool)

enum State {
	IDLE_TOP,
	DESCENDING,
	IDLE_BOTTOM,
	ASCENDING,
}

@export var top_y := 900.0
@export var bottom_y := 4300.0
@export_range(1.0, 30.0, 0.1) var travel_duration := 13.0
@export var interaction_hint_text := "按 [E] 启动升降梯"
@export_node_path("Area2D") var interaction_area_path := NodePath("InteractionArea")
@export_node_path("Area2D") var player_area_path := NodePath("PlayerArea")

var state := State.IDLE_TOP
var _player_inside := false
var _player: CharacterBody2D
var _player_original_parent: Node
var _travel_tween: Tween

@onready var interaction_area := get_node_or_null(interaction_area_path) as Area2D
@onready var player_area := get_node_or_null(player_area_path) as Area2D


func _ready() -> void:
	global_position.y = top_y
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	if player_area != null:
		player_area.body_entered.connect(_on_platform_body_entered)
		player_area.body_exited.connect(_on_platform_body_exited)


func configure_positions(elevator_top_y: float, elevator_bottom_y: float) -> void:
	top_y = elevator_top_y
	bottom_y = elevator_bottom_y
	if state == State.IDLE_TOP:
		global_position.y = top_y
	elif state == State.IDLE_BOTTOM:
		global_position.y = bottom_y


func interact() -> void:
	if state == State.IDLE_TOP:
		start_descent()
	elif state == State.IDLE_BOTTOM:
		start_ascent()


func start_descent() -> void:
	_start_travel(true)


func start_ascent() -> void:
	_start_travel(false)


func reset_to_top() -> void:
	_cancel_travel()
	_release_player()
	state = State.IDLE_TOP
	global_position.y = top_y
	state_changed.emit(state)


func teleport_to_bottom() -> void:
	_cancel_travel()
	_release_player()
	state = State.IDLE_BOTTOM
	global_position.y = bottom_y
	state_changed.emit(state)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var is_interact := event.is_action_pressed("interact") or key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	if not is_interact:
		return
	if _player_inside or OS.is_debug_build():
		interact()
		get_viewport().set_input_as_handled()


func _start_travel(descending: bool) -> void:
	if state in [State.DESCENDING, State.ASCENDING]:
		return
	_capture_player()
	state = State.DESCENDING if descending else State.ASCENDING
	state_changed.emit(state)
	travel_started.emit(descending)
	_hide_interaction_hint()
	var destination := bottom_y if descending else top_y
	_travel_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_travel_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_travel_tween.tween_property(self, "global_position:y", destination, travel_duration)
	_travel_tween.finished.connect(_on_travel_finished.bind(descending), CONNECT_ONE_SHOT)


func _on_travel_finished(descending: bool) -> void:
	state = State.IDLE_BOTTOM if descending else State.IDLE_TOP
	state_changed.emit(state)
	_release_player()
	_player_inside = false
	travel_finished.emit(descending)
	if _player_inside:
		_show_interaction_hint()


func _capture_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player_original_parent = _player.get_parent()
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_player.reparent(self, true)


func _release_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player_original_parent != null and is_instance_valid(_player_original_parent) and _player.get_parent() == self:
		_player.reparent(_player_original_parent, true)
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(true)


func _cancel_travel() -> void:
	if _travel_tween != null and _travel_tween.is_valid():
		_travel_tween.kill()
	_travel_tween = null


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player_inside = true
		_player = body as CharacterBody2D
		_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body == _player and state in [State.IDLE_TOP, State.IDLE_BOTTOM]:
		_player_inside = false
		_hide_interaction_hint()


func _on_platform_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player = body as CharacterBody2D


func _on_platform_body_exited(_body: Node2D) -> void:
	pass


func _show_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _find_top_hint() -> Node:
	var current: Node = self
	while current != null:
		var hint := current.get_node_or_null("GlobalUI/TopHintUI")
		if hint != null:
			return hint
		current = current.get_parent()
	return null


func _hint_id() -> String:
	return "lake_elevator_%s" % get_instance_id()
