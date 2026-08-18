class_name AlkeonExecutionEffect
extends Node2D

## Climax victory execution animation: Blood leaves stream in from off-screen, converge into a circular orb, and explode, dissolving the boss and restoring Danxin Gate.

signal execution_exploded
signal execution_completed

@onready var converge_particles: GPUParticles2D = $ConvergeParticles
@onready var burst_particles: GPUParticles2D = $BurstParticles
@onready var glow_orb: Sprite2D = $GlowOrb
@onready var shockwave_ring: Line2D = $ShockwaveRing

var _target_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	z_index = 50
	if glow_orb != null:
		glow_orb.visible = false
		glow_orb.scale = Vector2.ZERO
	if shockwave_ring != null:
		shockwave_ring.visible = false
	if converge_particles != null:
		converge_particles.emitting = false
	if burst_particles != null:
		burst_particles.emitting = false


func play_execution(center_pos: Vector2, on_exploded: Callable = Callable(), on_finished: Callable = Callable()) -> void:
	_target_pos = center_pos
	global_position = _target_pos

	# Stage 1: Convergence (1.6s)
	if glow_orb != null:
		glow_orb.visible = true
		glow_orb.scale = Vector2(0.1, 0.1)
		glow_orb.modulate = Color(1.5, 0.4, 0.2, 0.0)

	if converge_particles != null:
		converge_particles.emitting = true

	var tw1 := create_tween()
	# Orb expands and intensifies as leaves stream in
	if glow_orb != null:
		tw1.parallel().tween_property(glow_orb, "scale", Vector2(1.8, 1.8), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw1.parallel().tween_property(glow_orb, "modulate", Color(2.5, 1.8, 0.8, 1.0), 1.4)
		tw1.tween_property(glow_orb, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	tw1.tween_callback(func() -> void:
		_trigger_burst(on_exploded, on_finished)
	)


func _trigger_burst(on_exploded: Callable, on_finished: Callable) -> void:
	if converge_particles != null:
		converge_particles.emitting = false

	if glow_orb != null:
		glow_orb.visible = false

	# Burst particles
	if burst_particles != null:
		burst_particles.restart()
		burst_particles.emitting = true

	# Expanding Shockwave Ring
	if shockwave_ring != null:
		shockwave_ring.visible = true
		shockwave_ring.scale = Vector2(0.1, 0.1)
		shockwave_ring.modulate.a = 1.0
		var ring_tw := create_tween()
		ring_tw.parallel().tween_property(shockwave_ring, "scale", Vector2(4.5, 4.5), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ring_tw.parallel().tween_property(shockwave_ring, "modulate:a", 0.0, 0.75)
		ring_tw.tween_callback(func() -> void: shockwave_ring.visible = false)

	if on_exploded.is_valid():
		on_exploded.call()
	execution_exploded.emit()

	# Complete after burst particles finish
	get_tree().create_timer(1.8).timeout.connect(func() -> void:
		if on_finished.is_valid():
			on_finished.call()
		execution_completed.emit()
		queue_free()
	)
