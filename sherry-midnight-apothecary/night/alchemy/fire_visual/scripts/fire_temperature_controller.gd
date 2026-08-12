class_name FireTemperatureController
extends Node2D

const RENDER_Z_INDEX := -1

@export var minimum_temperature := 20.0
@export var maximum_temperature := 1000.0
@export var current_temperature := 20.0
@export var target_temperature := 20.0
@export var heating_response := 3.5
@export var cooling_response := 2.0
@export var animation_speed_min := 0.65
@export var animation_speed_max := 1.35
@export var visual_heat_curve: Curve
@export var state_library: FireStateLibrary
@export var maximum_light_energy := 1.3

## Public state is kept for the debug panel and any existing brewing UI hooks.
var animation_phase := 0.0
var lower_state := 0
var upper_state := 0
var state_blend := 0.0
var phase_speed := 0.65
var _active_a := -1
var _active_b := -1
var _frames_a: SpriteFrames
var _frames_b: SpriteFrames

@onready var fire_a: Sprite2D = $FireA
@onready var fire_b: Sprite2D = $FireB
@onready var fallback_furnace: Sprite2D = $FallbackFurnace
@onready var fire_light: PointLight2D = $FireLight
@onready var heat_distortion: CanvasItem = $HeatDistortion


func _ready() -> void:
	# Match the editor layer contract: background -2, furnace -1, equipment 0.
	z_index = RENDER_Z_INDEX
	visible = true
	modulate = Color.WHITE
	# This complete, opaque furnace frame is the runtime base. Animated states
	# are drawn above it; never hide the base merely because a dynamic resource
	# was assigned, since that could leave the entire furnace invisible.
	fallback_furnace.visible = true
	fire_a.visible = true
	fire_b.visible = true
	if state_library == null:
		push_error("FurnaceFireController requires a FireStateLibrary resource.")
		return
	state_library.load_states()
	if state_library.state_count() == 0:
		push_error("FurnaceFireController has no usable furnace fire states.")
		return
	snap_to_temperature(current_temperature)


func set_temperature(value: float) -> void:
	target_temperature = clampf(value, minimum_temperature, maximum_temperature)


func set_normalized_temperature(value: float) -> void:
	set_temperature(lerpf(minimum_temperature, maximum_temperature, clampf(value, 0.0, 1.0)))


func get_normalized_heat() -> float:
	var heat := clampf(inverse_lerp(minimum_temperature, maximum_temperature, current_temperature), 0.0, 1.0)
	return visual_heat_curve.sample(heat) if visual_heat_curve != null else heat


func snap_to_temperature(value: float) -> void:
	current_temperature = clampf(value, minimum_temperature, maximum_temperature)
	target_temperature = current_temperature
	_update_visual_state()


func _process(delta: float) -> void:
	var response := heating_response if target_temperature >= current_temperature else cooling_response
	current_temperature = lerpf(current_temperature, target_temperature, 1.0 - exp(-response * delta))
	var heat := get_normalized_heat()
	phase_speed = lerpf(animation_speed_min, animation_speed_max, heat)
	animation_phase = fmod(animation_phase + delta * phase_speed, 1.0)
	_update_visual_state()


func _update_visual_state() -> void:
	if state_library == null or state_library.state_count() == 0:
		return

	var count := state_library.state_count()
	var position := get_normalized_heat() * float(count - 1)
	lower_state = floori(position)
	upper_state = mini(lower_state + 1, count - 1)
	state_blend = smoothstep(0.0, 1.0, position - float(lower_state))
	_assign_state_sprites()
	_apply_phase()

	fire_a.modulate = Color(1.0, 1.0, 1.0, 1.0 - state_blend)
	fire_b.modulate = Color(1.0, 1.0, 1.0, state_blend)
	var light_heat := smoothstep(0.08, 1.0, get_normalized_heat())
	fire_light.energy = lerpf(0.0, maximum_light_energy, light_heat)
	if heat_distortion.material is ShaderMaterial:
		(heat_distortion.material as ShaderMaterial).set_shader_parameter("distortion_strength", lerpf(0.0, 0.22, light_heat))


func _assign_state_sprites() -> void:
	if _active_a != lower_state:
		_active_a = lower_state
		_frames_a = state_library.state(lower_state).get("fire") as SpriteFrames
	if _active_b != upper_state:
		_active_b = upper_state
		_frames_b = state_library.state(upper_state).get("fire") as SpriteFrames
	state_library.retain_states([lower_state, upper_state])


func _apply_phase() -> void:
	_set_frame_texture(fire_a, _frames_a)
	_set_frame_texture(fire_b, _frames_b)


func _set_frame_texture(sprite: Sprite2D, frames: SpriteFrames) -> void:
	if frames == null:
		return
	var frame_count := frames.get_frame_count(&"loop")
	if frame_count == 0:
		return
	var frame_index := floori(animation_phase * frame_count) % frame_count
	sprite.texture = frames.get_frame_texture(&"loop", frame_index)
