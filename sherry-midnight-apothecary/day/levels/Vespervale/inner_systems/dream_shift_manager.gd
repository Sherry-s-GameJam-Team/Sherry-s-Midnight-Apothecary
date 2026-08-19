class_name DreamShiftManager
extends Node2D

## Central State Controller for Vespervale Inner Hospital Corridor.
## Controls the primary Dream state and transient "Reality Intrusion" (现实入侵) disruptions.

signal dream_state_changed(is_dream: bool)
signal state_telegraph_started(next_is_dream: bool)
signal reality_intrusion_started
signal reality_intrusion_ended

enum State { REALITY_INTRUSION, TELEGRAPH, DREAM }

@export var start_in_dream: bool = true
## Duration range for the primary Dream State (seconds)
@export var dream_duration_min: float = 7.0
@export var dream_duration_max: float = 11.0
## Duration range for the transient Reality Intrusion (现实入侵短暂态, seconds)
@export var reality_intrusion_min: float = 2.5
@export var reality_intrusion_max: float = 4.0
@export var telegraph_time: float = 1.0
@export var auto_shift_enabled: bool = true

var current_state: State = State.DREAM
var _state_timer: float = 0.0
var _target_duration: float = 8.0
var _next_target_state: State = State.REALITY_INTRUSION

@onready var audio_synth: DreamAudioSynth = get_node_or_null("DreamAudioSynth")
@onready var screen_overlay: CanvasModulate = get_node_or_null("ScreenOverlay")
@onready var telegraph_vignette: ColorRect = get_node_or_null("CanvasLayer/TelegraphVignette")


func _ready() -> void:
	if start_in_dream:
		current_state = State.DREAM
		_target_duration = randf_range(dream_duration_min, dream_duration_max)
	else:
		current_state = State.REALITY_INTRUSION
		_target_duration = randf_range(reality_intrusion_min, reality_intrusion_max)

	_update_visuals(false)


func is_in_dream() -> bool:
	return current_state == State.DREAM


func is_in_reality_intrusion() -> bool:
	return current_state == State.REALITY_INTRUSION


func is_telegraphing() -> bool:
	return current_state == State.TELEGRAPH


func _process(delta: float) -> void:
	if not auto_shift_enabled:
		return

	_state_timer += delta

	match current_state:
		State.DREAM:
			if _state_timer >= _target_duration:
				_start_telegraph(State.REALITY_INTRUSION)
		State.REALITY_INTRUSION:
			if _state_timer >= _target_duration:
				_start_telegraph(State.DREAM)
		State.TELEGRAPH:
			_update_telegraph_pulse()
			if _state_timer >= telegraph_time:
				_complete_shift()


func _start_telegraph(next_state: State) -> void:
	current_state = State.TELEGRAPH
	_next_target_state = next_state
	_state_timer = 0.0

	var entering_dream := (next_state == State.DREAM)
	state_telegraph_started.emit(entering_dream)

	if audio_synth != null:
		audio_synth.play_telegraph_chime(entering_dream)

	if telegraph_vignette != null:
		telegraph_vignette.visible = true
		telegraph_vignette.modulate.a = 0.0
		var tw := create_tween()
		if not entering_dream:
			# Warning: Reality Intrusion incoming!
			telegraph_vignette.color = Color(0.85, 0.4, 0.2, 0.35)
		else:
			# Notice: Dream returning
			telegraph_vignette.color = Color(0.65, 0.2, 0.85, 0.28)
		tw.tween_property(telegraph_vignette, "modulate:a", 0.7, 0.4)
		tw.tween_property(telegraph_vignette, "modulate:a", 0.25, 0.3)
		tw.tween_property(telegraph_vignette, "modulate:a", 0.9, 0.3)


func _update_telegraph_pulse() -> void:
	if screen_overlay != null:
		var flicker := randf_range(0.85, 1.15)
		if _next_target_state == State.DREAM:
			screen_overlay.color = Color(0.75 * flicker, 0.65 * flicker, 0.95 * flicker, 1.0)
		else:
			screen_overlay.color = Color(0.85 * flicker, 0.75 * flicker, 0.65 * flicker, 1.0)


func _complete_shift() -> void:
	current_state = _next_target_state
	_state_timer = 0.0

	var in_dream := (current_state == State.DREAM)
	if in_dream:
		_target_duration = randf_range(dream_duration_min, dream_duration_max)
		reality_intrusion_ended.emit()
	else:
		_target_duration = randf_range(reality_intrusion_min, reality_intrusion_max)
		reality_intrusion_started.emit()

	if audio_synth != null:
		audio_synth.play_shift_swoosh(in_dream)

	_update_visuals(true)
	dream_state_changed.emit(in_dream)


func _update_visuals(animate: bool) -> void:
	var in_dream := (current_state == State.DREAM)

	if telegraph_vignette != null:
		if animate:
			var tw := create_tween()
			tw.tween_property(telegraph_vignette, "modulate:a", 0.0, 0.3)
			tw.tween_callback(func() -> void: telegraph_vignette.visible = false)
		else:
			telegraph_vignette.visible = false
			telegraph_vignette.modulate.a = 0.0

	if screen_overlay != null:
		var target_color := Color(0.82, 0.72, 1.0, 1.0) if in_dream else Color(0.72, 0.7, 0.75, 1.0)
		if animate:
			var tw := create_tween()
			tw.tween_property(screen_overlay, "color", target_color, 0.35)
		else:
			screen_overlay.color = target_color


func force_shift(to_dream: bool) -> void:
	current_state = State.DREAM if to_dream else State.REALITY_INTRUSION
	_state_timer = 0.0
	_target_duration = randf_range(dream_duration_min, dream_duration_max) if to_dream else randf_range(reality_intrusion_min, reality_intrusion_max)
	_update_visuals(false)
	dream_state_changed.emit(to_dream)
	if to_dream:
		reality_intrusion_ended.emit()
	else:
		reality_intrusion_started.emit()
