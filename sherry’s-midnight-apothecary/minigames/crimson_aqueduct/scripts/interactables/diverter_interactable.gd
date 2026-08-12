class_name DiverterInteractable
extends Area2D

signal direction_changed(diverter_id: StringName, direction: int)

@export var diverter_id: StringName = &"main_diverter"
@export var drag_threshold := 28.0
var direction := 0
var enabled := true
var _dragging := false
var _drag_origin := Vector2.ZERO

@onready var handle: Polygon2D = $Handle
@onready var direction_label: Label = $DirectionLabel


func _ready() -> void:
	input_event.connect(_on_input_event)
	_refresh()
	set_process_input(true)


func cancel_drag() -> void:
	_dragging = false
	_refresh()


func set_direction(value: int, emit_change := false) -> void:
	direction = clampi(value, 0, 1)
	_refresh()
	if emit_change:
		direction_changed.emit(diverter_id, direction)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_origin = event.position
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not enabled or not _dragging:
		return
	if event is InputEventMouseMotion:
		handle.position.x = clampf(event.position.x - _drag_origin.x, -36.0, 36.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(event.position)
		get_viewport().set_input_as_handled()


func _finish_drag(position: Vector2) -> void:
	if not _dragging:
		return
	var distance := position.x - _drag_origin.x
	_dragging = false
	if absf(distance) >= drag_threshold:
		set_direction(1 if distance > 0.0 else 0, true)
	else:
		_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	handle.position.x = -28.0 if direction == 0 else 28.0
	handle.color = Color("66b8b2") if direction == 0 else Color("b87552")
	direction_label.text = "净化渠" if direction == 0 else "泄洪渠"
