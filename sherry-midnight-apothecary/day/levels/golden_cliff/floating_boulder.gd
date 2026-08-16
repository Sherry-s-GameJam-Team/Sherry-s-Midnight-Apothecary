extends AnimatableBody2D

enum FloatState {
	UNSTABLE,
	STABLE
}

@export var state: FloatState = FloatState.UNSTABLE
@export var unstable_bob_amplitude: float = 18.0
@export var unstable_bob_speed: float = 1.8
@export var unstable_rot_amplitude: float = 0.035 # ~2 degrees
@export var unstable_horizontal_amplitude: float = 14.0
@export var unstable_horizontal_speed: float = 0.8

@export var stable_bob_amplitude: float = 3.0
@export var stable_bob_speed: float = 0.7
@export var stable_rot_amplitude: float = 0.0
@export var stable_horizontal_amplitude: float = 2.0
@export var stable_horizontal_speed: float = 0.3

@export var phase: float = 0.0

var _current_bob_amplitude: float = 18.0
var _current_bob_speed: float = 1.8
var _current_rot_amplitude: float = 0.035
var _current_horizontal_amplitude: float = 14.0
var _current_horizontal_speed: float = 0.8

var _origin := Vector2.ZERO
var _transition_tween: Tween

func _ready() -> void:
	_origin = position
	_apply_state_immediate()

func _apply_state_immediate() -> void:
	if state == FloatState.STABLE:
		_current_bob_amplitude = stable_bob_amplitude
		_current_bob_speed = stable_bob_speed
		_current_rot_amplitude = stable_rot_amplitude
		_current_horizontal_amplitude = stable_horizontal_amplitude
		_current_horizontal_speed = stable_horizontal_speed
	else:
		_current_bob_amplitude = unstable_bob_amplitude
		_current_bob_speed = unstable_bob_speed
		_current_rot_amplitude = unstable_rot_amplitude
		_current_horizontal_amplitude = unstable_horizontal_amplitude
		_current_horizontal_speed = unstable_horizontal_speed

func set_stable(is_stable: bool) -> void:
	state = FloatState.STABLE if is_stable else FloatState.UNSTABLE
	var target_bob_amp := stable_bob_amplitude if is_stable else unstable_bob_amplitude
	var target_bob_spd := stable_bob_speed if is_stable else unstable_bob_speed
	var target_rot_amp := stable_rot_amplitude if is_stable else unstable_rot_amplitude
	var target_hor_amp := stable_horizontal_amplitude if is_stable else unstable_horizontal_amplitude
	var target_hor_spd := stable_horizontal_speed if is_stable else unstable_horizontal_speed
	
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(self, "_current_bob_amplitude", target_bob_amp, 1.4)
	_transition_tween.tween_property(self, "_current_bob_speed", target_bob_spd, 1.4)
	_transition_tween.tween_property(self, "_current_rot_amplitude", target_rot_amp, 1.4)
	_transition_tween.tween_property(self, "_current_horizontal_amplitude", target_hor_amp, 1.4)
	_transition_tween.tween_property(self, "_current_horizontal_speed", target_hor_spd, 1.4)

func _physics_process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var hor_offset := sin(t * _current_horizontal_speed + phase) * _current_horizontal_amplitude
	var ver_offset := sin(t * _current_bob_speed + phase) * _current_bob_amplitude
	var rot_offset := cos(t * _current_bob_speed * 0.85 + phase) * _current_rot_amplitude
	
	position = _origin + Vector2(hor_offset, ver_offset)
	rotation = rot_offset
