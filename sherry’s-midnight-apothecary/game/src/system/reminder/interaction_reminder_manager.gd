extends Node

const REMINDER_SCENE := preload("res://game/src/system/reminder/operation_reminder.tscn")

var reminder: CanvasLayer = null
var active_owner: Object = null
var active_message := ""


func show_interaction(owner: Object, message: String) -> void:
	if owner == null or message.strip_edges().is_empty():
		return
	if active_owner == owner and active_message == message:
		return

	active_owner = owner
	active_message = message
	_ensure_reminder()
	if reminder.has_method("show_persistent_reminder"):
		reminder.call("show_persistent_reminder", message)
	else:
		reminder.call("hide_now")
		reminder.call("show_reminder", message, 3600.0)


func hide_interaction(owner: Object) -> void:
	if active_owner != owner:
		return

	active_owner = null
	active_message = ""
	if reminder == null:
		return
	if reminder.has_method("hide_persistent_reminder"):
		reminder.call("hide_persistent_reminder")
	else:
		reminder.call("hide_now")


func clear_all() -> void:
	active_owner = null
	active_message = ""
	if reminder != null and reminder.has_method("hide_now"):
		reminder.call("hide_now")


func _ensure_reminder() -> void:
	if reminder != null and is_instance_valid(reminder):
		return

	reminder = REMINDER_SCENE.instantiate() as CanvasLayer
	reminder.name = "OperationReminder"
	add_child(reminder)
