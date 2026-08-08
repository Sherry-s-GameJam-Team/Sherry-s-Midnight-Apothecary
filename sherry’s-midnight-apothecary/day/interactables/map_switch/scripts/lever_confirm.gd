extends Node2D
class_name LeverConfirm

signal committed
signal pull_changed(ratio: float)

var enabled := false
var pull_distance := 78.0
var commit_threshold := 0.82
var visual_scale := Vector2(0.80, 0.80)

@onready var _sprite: Sprite2D = get_node_or_null("LeverSprite") as Sprite2D
var _dragging := false
var _drag_start_y := 0.0
var _drag_start_ratio := 0.0
var _pull_ratio := 0.0
var _hit_half_size := Vector2(55.0, 175.0)

func _ready() -> void:
	if _sprite != null:
		_sprite.scale = visual_scale
	set_enabled(false)

func set_enabled(value: bool) -> void:
	enabled = value
	modulate = Color.WHITE if enabled else Color(0.48, 0.48, 0.54, 0.62)
	if not enabled:
		_dragging = false
		_return_home()

func _unhandled_input(event: InputEvent) -> void:
	if _sprite == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if enabled and _is_mouse_over():
				_dragging = true
				_drag_start_y = to_local(get_global_mouse_position()).y
				_drag_start_ratio = _pull_ratio
				get_viewport().set_input_as_handled()
		elif _dragging:
			_dragging = false
			if enabled and _pull_ratio >= commit_threshold:
				committed.emit()
			_return_home()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var local_y := to_local(get_global_mouse_position()).y
		_pull_ratio = clampf(_drag_start_ratio + (local_y - _drag_start_y) / pull_distance, 0.0, 1.0)
		_apply_visual()
		pull_changed.emit(_pull_ratio)
		get_viewport().set_input_as_handled()

func _is_mouse_over() -> bool:
	var p := to_local(get_global_mouse_position())
	return Rect2(-_hit_half_size, _hit_half_size * 2.0).has_point(p)

func _apply_visual() -> void:
	if _sprite == null:
		return
	_sprite.position.y = _pull_ratio * pull_distance
	_sprite.rotation = deg_to_rad(_pull_ratio * 4.0)

func _return_home() -> void:
	if _sprite == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "position:y", 0.0, 0.22)
	tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.22)
	tween.tween_callback(func() -> void:
		_pull_ratio = 0.0
		pull_changed.emit(0.0)
	)
