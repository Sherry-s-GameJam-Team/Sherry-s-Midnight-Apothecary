class_name PurifierInteractable
extends Area2D

signal use_requested(purifier_id: StringName)

@export var purifier_id: StringName = &"purifier_basin"
var enabled := true
var active := false

@onready var basin: Polygon2D = $Basin
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	input_event.connect(_on_input_event)


func set_active(value: bool) -> void:
	active = value
	basin.color = Color("69c9c1") if active else Color("456d70")
	status_label.text = "符文运转中" if active else "净化槽"


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		use_requested.emit(purifier_id)
		get_viewport().set_input_as_handled()
