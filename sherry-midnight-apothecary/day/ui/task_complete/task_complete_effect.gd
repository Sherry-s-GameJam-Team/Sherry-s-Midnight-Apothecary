extends Control

signal effect_finished

@export_range(0.5, 5.0, 0.1) var effect_duration := 2.4
@export_range(8, 64, 1) var sparkle_count := 32
@export var gold := Color(1.0, 0.78, 0.28, 1.0)
@export var mint := Color(0.42, 1.0, 0.72, 1.0)

var _elapsed := 0.0
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	hide()


func play_effect() -> void:
	_elapsed = 0.0
	_active = true
	show()
	set_process(true)
	queue_redraw()


func stop_effect() -> void:
	_active = false
	set_process(false)
	hide()
	queue_redraw()


func is_playing() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= effect_duration:
		_active = false
		set_process(false)
		effect_finished.emit()


func _draw() -> void:
	if not visible:
		return
	var center := size * 0.5
	var progress := clampf(_elapsed / effect_duration, 0.0, 1.0)
	var burst_progress := 1.0 - pow(1.0 - minf(progress * 1.8, 1.0), 3.0)
	var fade := clampf(1.0 - maxf(progress - 0.58, 0.0) / 0.42, 0.0, 1.0)
	var viewport_radius := minf(size.x * 0.43, size.y * 0.68)

	for ring_index in range(3):
		var stagger := clampf(progress * 1.55 - float(ring_index) * 0.13, 0.0, 1.0)
		var ring_radius := lerpf(132.0, viewport_radius * (0.72 + float(ring_index) * 0.14), stagger)
		var ring_alpha := (1.0 - stagger) * 0.7 * fade
		draw_arc(center, ring_radius, 0.0, TAU, 96, Color(gold, ring_alpha), 3.0 + float(2 - ring_index), true)

	var ray_alpha := (1.0 - burst_progress) * 0.8
	for ray_index in range(16):
		var ray_angle := TAU * float(ray_index) / 16.0
		var inner := center + Vector2.from_angle(ray_angle) * lerpf(145.0, 265.0, burst_progress)
		var outer := center + Vector2.from_angle(ray_angle) * lerpf(250.0, viewport_radius * 1.08, burst_progress)
		draw_line(inner, outer, Color(mint if ray_index % 2 else gold, ray_alpha), 3.0, true)

	for index in range(sparkle_count):
		var seed := float(index) * 2.399963
		var wobble := sin(float(index) * 7.31) * 0.16
		var angle := seed + wobble + progress * (0.22 if index % 2 == 0 else -0.18)
		var distance_ratio := 0.72 + fposmod(float(index) * 0.381966, 0.42)
		var distance := lerpf(96.0, viewport_radius * distance_ratio, burst_progress)
		var position := center + Vector2.from_angle(angle) * distance
		position.y += progress * progress * (24.0 + float(index % 5) * 8.0)
		var twinkle := 0.55 + 0.45 * sin(_elapsed * 10.0 + float(index))
		var alpha := fade * twinkle
		var radius := 2.5 + float(index % 4) * 1.3
		var color := Color(mint if index % 3 == 0 else gold, alpha)
		draw_circle(position, radius, color)
		if index % 4 == 0:
			draw_line(position - Vector2(radius * 2.4, 0.0), position + Vector2(radius * 2.4, 0.0), color, 1.5, true)
			draw_line(position - Vector2(0.0, radius * 2.4), position + Vector2(0.0, radius * 2.4), color, 1.5, true)
