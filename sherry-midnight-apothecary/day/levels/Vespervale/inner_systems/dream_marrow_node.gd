class_name DreamMarrowNode
extends Area2D

## Zone 5 Climax Node: Ethereal marrow crystal node shielded by iron bars in Reality,
## accessible only during Dream state. Interacting/triggering it unlocks the exit ward gate.

signal activated

@export var is_activated: bool = false

var _is_dream: bool = false
var _player_in_range: bool = false
var _pulse_time: float = 0.0

@onready var barrier_collider: StaticBody2D = get_node_or_null("BarrierCollider")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var manager := _find_shift_manager()
	if manager != null:
		manager.dream_state_changed.connect(_on_dream_state_changed)
		_set_dream_state(manager.is_in_dream())
	else:
		_set_dream_state(false)


func _unhandled_input(event: InputEvent) -> void:
	if is_activated or not _player_in_range or not _is_dream:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		activate_node()


func _physics_process(delta: float) -> void:
	_pulse_time += delta * 4.0
	queue_redraw()


func _draw() -> void:
	var core_color := Color(0.9, 0.4, 1.0, 1.0) if is_activated else (Color(0.8, 0.3, 0.95, 0.9) if _is_dream else Color(0.5, 0.45, 0.6, 0.7))
	var glow_size := 32.0 + sin(_pulse_time) * 4.0
	# Outer pulse glow
	draw_circle(Vector2.ZERO, glow_size, Color(core_color.r, core_color.g, core_color.b, 0.35))
	# Inner crystal diamond
	var diamond := PackedVector2Array([
		Vector2(0, -22),
		Vector2(16, 0),
		Vector2(0, 22),
		Vector2(-16, 0),
	])
	draw_colored_polygon(diamond, core_color)
	draw_polyline(diamond, Color(1.0, 0.9, 1.0, 0.9), 2.0)

	# If in reality, draw iron bars over it
	if not _is_dream and not is_activated:
		for x in [-14.0, 0.0, 14.0]:
			draw_line(Vector2(x, -28), Vector2(x, 28), Color(0.25, 0.22, 0.3, 0.9), 3.5)


func activate_node() -> void:
	if is_activated:
		return
	is_activated = true
	activated.emit()

	var manager := _find_shift_manager()
	if manager != null and manager.audio_synth != null:
		manager.audio_synth.play_crystal_pulse()

	if prompt_label != null:
		prompt_label.visible = false

	var top_hint := _find_top_hint()
	if top_hint != null and top_hint.has_method("hide_interaction_hint"):
		top_hint.call("hide_interaction_hint", "dream_marrow_node")

	var env := _find_environment()
	if env != null and env.has_signal("objective_updated"):
		env.emit_signal("objective_updated", "梦髓节点已激活！", "出口大门已解锁，在下一轮切换前冲出病栋！")


func _on_dream_state_changed(in_dream: bool) -> void:
	_set_dream_state(in_dream)


func _set_dream_state(in_dream: bool) -> void:
	_is_dream = in_dream
	if barrier_collider != null:
		# Barrier bars block in reality, dissolve in dream
		var col := barrier_collider.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col != null:
			col.set_deferred("disabled", in_dream or is_activated)

	_update_prompt()
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.is_in_group("player") or body.name == "Player"):
		_player_in_range = true
		_update_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and (body.is_in_group("player") or body.name == "Player"):
		_player_in_range = false
		_update_prompt()


func _update_prompt() -> void:
	var can_interact := _player_in_range and _is_dream and not is_activated
	var top_hint := _find_top_hint()
	if top_hint != null:
		if can_interact:
			if top_hint.has_method("show_interaction_hint"):
				top_hint.call("show_interaction_hint", "dream_marrow_node", "按 E 激活梦髓节点")
		else:
			if top_hint.has_method("hide_interaction_hint"):
				top_hint.call("hide_interaction_hint", "dream_marrow_node")

	if prompt_label != null:
		prompt_label.visible = can_interact


func _find_top_hint() -> Node:
	var cur: Node = self
	while cur != null:
		var hint := cur.get_node_or_null("PauseMenuLayer/TopHintUI")
		if hint == null:
			hint = cur.get_node_or_null("TopHintUI")
		if hint != null:
			return hint
		cur = cur.get_parent()
	return null


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
