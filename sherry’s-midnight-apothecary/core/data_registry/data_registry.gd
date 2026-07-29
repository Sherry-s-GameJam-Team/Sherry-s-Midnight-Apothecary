class_name DataRegistry
extends RefCounted

var _definitions: Dictionary = {}
var _errors: PackedStringArray = []
var report_errors_to_engine := true


func clear() -> void:
	_definitions.clear()
	_errors.clear()


func register_all(definitions: Array[Resource]) -> bool:
	var valid := true
	for definition: Resource in definitions:
		valid = register_definition(definition) and valid
	return valid


func register_definition(definition: Resource) -> bool:
	if definition == null:
		return _record_error("Cannot register a null definition.")
	var stable_id := _read_stable_id(definition)
	if stable_id.is_empty():
		return _record_error("Definition %s has an empty stable ID." % definition.resource_path)
	if _definitions.has(stable_id):
		return _record_error("Duplicate definition ID '%s'." % stable_id)
	if _has_missing_or_invalid_packed_scene(definition):
		return _record_error("Definition '%s' has a missing or invalid PackedScene." % stable_id)
	_definitions[stable_id] = definition
	return true


func get_definition(stable_id: StringName) -> Resource:
	return _definitions.get(stable_id) as Resource


func has_definition(stable_id: StringName) -> bool:
	return _definitions.has(stable_id)


func get_errors() -> PackedStringArray:
	return _errors.duplicate()


func size() -> int:
	return _definitions.size()


func _read_stable_id(definition: Resource) -> StringName:
	for property: Dictionary in definition.get_property_list():
		var property_name := StringName(property.get("name", &""))
		if property_name == &"id":
			var value: Variant = definition.get(property_name)
			if value is StringName or value is String:
				return StringName(value)
			return &""
	for property: Dictionary in definition.get_property_list():
		var property_name := StringName(property.get("name", &""))
		if property_name.ends_with("_id"):
			var value: Variant = definition.get(property_name)
			if value is StringName or value is String:
				return StringName(value)
	return &""


func _has_missing_or_invalid_packed_scene(definition: Resource) -> bool:
	for property: Dictionary in definition.get_property_list():
		if int(property.get("type", TYPE_NIL)) != TYPE_OBJECT:
			continue
		if int(property.get("hint", PROPERTY_HINT_NONE)) != PROPERTY_HINT_RESOURCE_TYPE:
			continue
		if str(property.get("hint_string", "")) != "PackedScene":
			continue
		var scene_value: Variant = definition.get(property.get("name", &""))
		if scene_value == null or not scene_value is PackedScene:
			return true
	return false


func _record_error(message: String) -> bool:
	_errors.append(message)
	if report_errors_to_engine:
		push_error("DataRegistry: %s" % message)
	return false
