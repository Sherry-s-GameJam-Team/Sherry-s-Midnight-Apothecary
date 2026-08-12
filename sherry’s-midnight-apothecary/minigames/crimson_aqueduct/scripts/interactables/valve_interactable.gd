class_name ValveInteractable
extends Area2D

signal state_changed(valve_id: StringName, openness: float)

enum ValveState { OPEN, HALF, CLOSED }

@export var valve_id: StringName = &"spring_gate"
@export var initial_state := ValveState.OPEN
var state := ValveState.OPEN
var enabled := true

@onready var wheel: Polygon2D = $Wheel
@onready var state_label: Label = $StateLabel


func _ready() -> void:
	state = initial_state
	input_event.connect(_on_input_event)
	_refresh()


func cycle_state() -> void:
	if not enabled:
		return
	state = (state + 1) % ValveState.size()
	_refresh()
	state_changed.emit(valve_id, get_openness())


func get_openness() -> float:
	return [1.0, 0.5, 0.0][state]


func set_state(value: ValveState) -> void:
	state = value
	_refresh()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cycle_state()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not is_node_ready():
		return
	wheel.rotation = [0.0, PI / 4.0, PI / 2.0][state]
	wheel.color = [Color("8fbf9b"), Color("c3a25c"), Color("8b4d48")][state]
	state_label.text = ["开启", "半开", "关闭"][state]
