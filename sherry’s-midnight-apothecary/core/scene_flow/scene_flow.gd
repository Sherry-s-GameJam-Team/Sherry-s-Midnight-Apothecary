class_name SceneFlow
extends Node

signal transition_started(scene: PackedScene)
signal transition_completed(mode_root: Node)
signal transition_failed(message: String)

var _mode_slot: Node
var _current_mode: Node
var _transition_locked := false


func configure(mode_slot: Node) -> void:
	_mode_slot = mode_slot


func is_transitioning() -> bool:
	return _transition_locked


func get_current_mode() -> Node:
	return _current_mode


func switch_mode(scene: PackedScene) -> bool:
	if _transition_locked:
		return false
	if scene == null:
		transition_failed.emit("Cannot switch mode: PackedScene is null.")
		return false
	if not is_instance_valid(_mode_slot):
		transition_failed.emit("Cannot switch mode: CurrentModeSlot is not configured.")
		return false

	_transition_locked = true
	transition_started.emit(scene)
	var next_mode := scene.instantiate()
	if next_mode == null:
		_transition_locked = false
		transition_failed.emit("Cannot switch mode: PackedScene could not be instantiated.")
		return false

	var previous_mode := _current_mode
	_mode_slot.add_child(next_mode)
	await next_mode.ready
	_current_mode = next_mode

	if is_instance_valid(previous_mode):
		previous_mode.queue_free()
		await previous_mode.tree_exited

	_transition_locked = false
	transition_completed.emit(_current_mode)
	return true


func clear_mode() -> bool:
	if _transition_locked:
		return false
	_transition_locked = true
	var previous_mode := _current_mode
	_current_mode = null
	if is_instance_valid(previous_mode):
		previous_mode.queue_free()
		await previous_mode.tree_exited
	_transition_locked = false
	transition_completed.emit(null)
	return true

