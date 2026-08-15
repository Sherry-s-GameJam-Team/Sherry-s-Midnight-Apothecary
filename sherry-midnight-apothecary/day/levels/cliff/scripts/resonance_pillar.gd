class_name CliffResonancePillar
extends Node2D

signal stabilized(pillar_id: StringName)
signal resonance_burst(source_id: StringName, intensity: float)

const WAVE_SCENE := preload("res://day/levels/cliff/effects/resonance_wave.tscn")

@export var pillar_id: StringName = &"pillar"
@export var pulse_interval := 2.8
@export var first_pulse_delay := 1.4
@export var warning_time := 0.7
@export var charge_time := 0.5
@export var wave_speed := 920.0
@export var wave_range := 980.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var interact_area: Area2D = $InteractArea
@onready var label: Label = $Label
@onready var pulse_origin: Marker2D = $PulseOrigin
@onready var burst_ring: Line2D = $BurstRing
@onready var charge_audio: AudioStreamPlayer2D = $Audio/ResonanceCharge
@onready var burst_audio: AudioStreamPlayer2D = $Audio/ResonanceBurst
@onready var wave_audio: AudioStreamPlayer2D = $Audio/ResonanceWave

var _player_inside := false
var _stabilized := false
var _pulse_timer := 0.0
var _sprite_material: ShaderMaterial
var _warning_active := false


func _ready() -> void:
	add_to_group("cliff_resonance_pillars")
	_sprite_material = sprite.material.duplicate() as ShaderMaterial
	sprite.material = _sprite_material
	_pulse_timer = first_pulse_delay
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	_refresh_label()


func _process(delta: float) -> void:
	if _stabilized:
		return
	_pulse_timer -= delta
	var total_charge_time := warning_time + charge_time
	if _pulse_timer <= total_charge_time:
		var t := clampf(1.0 - (_pulse_timer / maxf(total_charge_time, 0.01)), 0.0, 1.0)
		_sprite_material.set_shader_parameter("charge", t)
		if not _warning_active:
			_warning_active = true
			_play_warning_shake()
	else:
		_warning_active = false
		_sprite_material.set_shader_parameter("charge", 0.0)
	if _pulse_timer <= 0.0:
		_emit_resonance_wave()
		_pulse_timer = pulse_interval


func _input(event: InputEvent) -> void:
	if _stabilized or not _player_inside or get_tree().has_meta("day_modal_input_locked"):
		return
	if _is_interact_event(event):
		get_viewport().set_input_as_handled()
		set_stabilized(true)


func set_stabilized(value: bool, silent := false) -> void:
	if _stabilized == value:
		return
	_stabilized = value
	if _stabilized:
		sprite.modulate = Color(0.72, 0.88, 0.95, 1.0)
		_sprite_material.set_shader_parameter("charge", 0.0)
		for wave: Node in get_tree().get_nodes_in_group("cliff_resonance_wave"):
			if is_instance_valid(wave) and wave.global_position.distance_to(global_position) < wave_range + 120.0:
				wave.queue_free()
	else:
		sprite.modulate = Color.WHITE
		_pulse_timer = first_pulse_delay
	_refresh_label()
	if _stabilized and not silent:
		stabilized.emit(pillar_id)


func is_stabilized() -> bool:
	return _stabilized


func _emit_resonance_wave() -> void:
	if burst_audio.stream != null:
		burst_audio.play()
	_spawn_wave(Vector2.LEFT)
	_spawn_wave(Vector2.RIGHT)
	if wave_audio.stream != null:
		wave_audio.play()
	resonance_burst.emit(pillar_id, 1.0)
	_sprite_material.set_shader_parameter("burst", 1.0)
	var flash := create_tween()
	flash.tween_method(func(value: float) -> void: _sprite_material.set_shader_parameter("burst", value), 1.0, 0.0, 0.22)
	burst_ring.visible = true
	burst_ring.scale = Vector2.ONE
	burst_ring.modulate.a = 1.0
	var ring_tween := create_tween().set_parallel(true)
	ring_tween.tween_property(burst_ring, "scale", Vector2.ONE * 4.4, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(burst_ring, "modulate:a", 0.0, 0.34)
	ring_tween.chain().tween_callback(func() -> void: burst_ring.visible = false)


func debug_trigger_burst() -> void:
	if not _stabilized:
		_emit_resonance_wave()


func _play_warning_shake() -> void:
	if charge_audio.stream != null:
		charge_audio.play()
	var base_position := sprite.position
	var tween := create_tween()
	tween.tween_property(sprite, "position:x", base_position.x - 2.0, 0.08)
	tween.tween_property(sprite, "position:x", base_position.x + 2.0, 0.08)
	tween.tween_property(sprite, "position:x", base_position.x - 3.0, 0.07)
	tween.tween_property(sprite, "position:x", base_position.x + 3.0, 0.07)
	tween.tween_property(sprite, "position", base_position, 0.06)


func _spawn_wave(wave_direction: Vector2) -> void:
	var wave := WAVE_SCENE.instantiate() as CliffResonanceWave
	if wave == null:
		return
	wave.direction = wave_direction
	wave.speed = wave_speed
	wave.max_distance = wave_range
	var wave_parent := get_node_or_null("../../Hazards/ResonanceWaves")
	if wave_parent == null:
		wave_parent = get_parent()
	wave_parent.add_child(wave)
	wave.global_position = pulse_origin.global_position


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_refresh_label()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_refresh_label()


func _refresh_label() -> void:
	if label == null:
		return
	label.visible = _player_inside
	label.text = "共鸣已稳定" if _stabilized else "按 [E] 校准共鸣晶柱"


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)
