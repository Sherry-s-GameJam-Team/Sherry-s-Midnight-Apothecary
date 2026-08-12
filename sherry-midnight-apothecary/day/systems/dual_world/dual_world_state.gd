class_name DualWorldState
extends Node

signal state_changed(key: StringName, value: Variant)

var _values: Dictionary = {}


func set_state(key: StringName, value: Variant) -> bool:
	if key == &"" or _values.get(key) == value:
		return false
	_values[key] = value
	state_changed.emit(key, value)
	return true


func get_state(key: StringName, default_value: Variant = null) -> Variant:
	return _values.get(key, default_value)


func set_flag(key: StringName, enabled := true) -> bool:
	return set_state(key, enabled)


func is_flag_set(key: StringName) -> bool:
	return bool(_values.get(key, false))


func clear() -> void:
	var changed_keys := _values.keys()
	_values.clear()
	for key: Variant in changed_keys:
		state_changed.emit(StringName(key), null)

