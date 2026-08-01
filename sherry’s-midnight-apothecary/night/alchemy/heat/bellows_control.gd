class_name BellowsControl
extends Control

signal bellows_pumped(effective_strength: float)

@export_group("Bellows Input")
@export_range(0.01, 1.0, 0.01) var bellows_strength := 0.28
@export_range(0.0, 1.0, 0.01) var fatigue_per_pump := 0.12
@export_range(0.0, 2.0, 0.01) var fatigue_recovery := 0.28
@export_range(0.1, 1.0, 0.01) var minimum_efficiency := 0.70

@export_group("Bellows Sprite Animation")
@export var bellows_sprite_sheet: Texture2D
@export_range(0.20, 1.50, 0.01) var pump_cycle_duration := 0.32
@export_range(2, 60, 1) var sprite_frame_count := 15
@export var sprite_frame_size := Vector2i(512, 288)
@export var sprite_flip_horizontal := false

var bellows_fatigue := 0.0
var _pump_cycle_active := false
var _pump_cycle_elapsed := 0.0

const BELLOWS_SPRITE_SHEET_PATH := "res://night/art/alchemy/bellows/bellows_pump_sheet.png"


func _ready() -> void:
	if bellows_sprite_sheet == null:
		bellows_sprite_sheet = load(BELLOWS_SPRITE_SHEET_PATH) as Texture2D
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _process(delta: float) -> void:
	# A completed stroke naturally refills the bellows. Recovering during the
	# return animation prevents rapid, valid pumping from permanently collapsing
	# to a weak late-brew output.
	bellows_fatigue = move_toward(bellows_fatigue, 0.0, fatigue_recovery * delta)
	if _pump_cycle_active:
		_pump_cycle_elapsed += delta
		if _pump_cycle_elapsed >= pump_cycle_duration:
			_pump_cycle_active = false
			_pump_cycle_elapsed = pump_cycle_duration
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_pump()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_SPACE:
		_try_pump()
		get_viewport().set_input_as_handled()


func _try_pump() -> bool:
	if mouse_filter == Control.MOUSE_FILTER_IGNORE or _pump_cycle_active:
		return false
	_emit_pump()
	_play_pump_cycle()
	return true


func pump_for_test() -> void:
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	_emit_pump()
	_play_pump_cycle()


func set_pumping_enabled(enabled: bool) -> void:
	var was_enabled := mouse_filter != Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if enabled and not was_enabled:
		bellows_fatigue = 0.0


func _emit_pump() -> void:
	var efficiency := lerpf(1.0, minimum_efficiency, bellows_fatigue)
	bellows_pumped.emit(bellows_strength * efficiency)
	bellows_fatigue = clampf(bellows_fatigue + fatigue_per_pump, 0.0, 1.0)


func _play_pump_cycle() -> void:
	_pump_cycle_active = true
	_pump_cycle_elapsed = 0.0
	queue_redraw()


func _sprite_frame_index() -> int:
	var last_frame: int = maxi(sprite_frame_count - 1, 0)
	if _pump_cycle_active:
		var progress := clampf(_pump_cycle_elapsed / maxf(pump_cycle_duration, 0.01), 0.0, 1.0)
		return clampi(roundi(progress * float(last_frame)), 0, last_frame)
	return 0


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if bellows_sprite_sheet == null or sprite_frame_size.x <= 0 or sprite_frame_size.y <= 0:
		return
	var source_rect := Rect2(
		Vector2(_sprite_frame_index() * sprite_frame_size.x, 0.0),
		Vector2(sprite_frame_size),
	)
	var target_size := Vector2(rect.size.x, rect.size.x * float(sprite_frame_size.y) / float(sprite_frame_size.x))
	if sprite_flip_horizontal:
		draw_set_transform(rect.get_center(), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(bellows_sprite_sheet, Rect2(-target_size * 0.5, target_size), source_rect)
		draw_set_transform(Vector2.ZERO)
	else:
		var target_rect := Rect2(rect.get_center() - target_size * 0.5, target_size)
		draw_texture_rect_region(bellows_sprite_sheet, target_rect, source_rect)
