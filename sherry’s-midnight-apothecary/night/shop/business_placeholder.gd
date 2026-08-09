class_name BusinessPlaceholder
extends Control

signal request_return


func _on_return_button_pressed() -> void:
	request_return.emit()
