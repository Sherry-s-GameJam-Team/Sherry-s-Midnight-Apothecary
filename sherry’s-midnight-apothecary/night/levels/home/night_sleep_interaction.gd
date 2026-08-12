class_name NightSleepInteraction
extends Area2D

@export var interaction_hint_text := "按[E]睡觉"
@export_node_path("AnimatedSprite2D") var sleep_animation_path: NodePath
@export_node_path("CanvasItem") var bed_visual_path: NodePath

var _player: CharacterBody2D
var _player_inside := false
var _sleeping := false
var _transition_requested := false
var _sleep_animation: AnimatedSprite2D
var _bed_visual: CanvasItem
var _player_visual: CanvasItem


func _ready() -> void:
	_sleep_animation = get_node_or_null(sleep_animation_path) as AnimatedSprite2D
	_bed_visual = get_node_or_null(bed_visual_path) as CanvasItem
	if _sleep_animation == null or _bed_visual == null:
		push_error("NightSleepInteraction requires sleep animation and bed visual paths.")
		return
	_sleep_animation.hide()
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_sleep_animation.animation_finished.connect(_on_sleep_animation_finished)


func _input(event: InputEvent) -> void:
	if _sleeping or not _player_inside or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	_start_sleep()


func _exit_tree() -> void:
	_hide_interaction_hint()


func _on_body_entered(body: Node2D) -> void:
	if _sleeping or not (body is CharacterBody2D and body.name == "Player"):
		return
	_player = body as CharacterBody2D
	_player_inside = true
	_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body != _player or _sleeping:
		return
	_player_inside = false
	_hide_interaction_hint()


func _start_sleep() -> void:
	if _sleep_animation.sprite_frames == null or not _sleep_animation.sprite_frames.has_animation(&"sleep"):
		push_error("NightSleepInteraction requires the sleep animation.")
		return
	_sleeping = true
	monitoring = false
	_hide_interaction_hint()
	get_tree().set_meta("day_modal_input_locked", true)
	_player_visual = _player.get_node_or_null("SherryPresentation") as CanvasItem
	_player.set_physics_process(false)
	_player.set_process_input(false)
	_player.set_process_unhandled_input(false)
	_player.set_process_unhandled_key_input(false)
	if _player_visual != null:
		_player_visual.hide()
	_bed_visual.hide()
	_sleep_animation.show()
	_sleep_animation.frame = 0
	_sleep_animation.frame_progress = 0.0
	_sleep_animation.play(&"sleep")


func _on_sleep_animation_finished() -> void:
	if not _sleeping or _transition_requested:
		return
	_transition_requested = true
	var bedroom := _find_bedroom()
	if bedroom != null:
		bedroom.request_sleep()


func is_sleeping() -> bool:
	return _sleeping


func _find_bedroom() -> NightBedroom:
	var current := get_parent()
	while current != null:
		if current is NightBedroom:
			return current as NightBedroom
		current = current.get_parent()
	return null


func _show_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return null


func _hint_id() -> String:
	return "night_sleep_%s" % get_instance_id()
