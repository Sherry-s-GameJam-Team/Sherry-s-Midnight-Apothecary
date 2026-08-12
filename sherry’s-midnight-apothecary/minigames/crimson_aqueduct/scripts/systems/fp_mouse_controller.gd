class_name FPMouseController
extends Node

signal mode_changed(mode: StringName)
signal interaction_cancelled

const MODE_NONE := &"none"
const MODE_PURIFIER := &"purifier"
const MODE_SEALANT := &"sealant"

var current_mode: StringName = MODE_NONE
var enabled := true


func set_mode(mode: StringName) -> void:
	if not enabled or not [MODE_NONE, MODE_PURIFIER, MODE_SEALANT].has(mode):
		return
	current_mode = mode
	mode_changed.emit(current_mode)


func cancel() -> void:
	current_mode = MODE_NONE
	mode_changed.emit(current_mode)
	interaction_cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel()
		get_viewport().set_input_as_handled()
