class_name CrackInteractable
extends Area2D

signal seal_requested(crack_id: StringName)

@export var crack_id: StringName = &"upper_crack"
var enabled := true
var sealed := false

@onready var crack_line: Line2D = $CrackLine
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	input_event.connect(_on_input_event)


func set_sealed(value: bool) -> void:
	sealed = value
	crack_line.default_color = Color("718678") if sealed else Color("d13d42")
	status_label.text = "已封堵" if sealed else "污染裂缝"


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if enabled and not sealed and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		seal_requested.emit(crack_id)
		get_viewport().set_input_as_handled()
