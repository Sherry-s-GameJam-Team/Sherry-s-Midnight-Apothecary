class_name NightHome
extends Node2D

signal business_requested
signal alchemy_requested
signal production_requested
signal bedroom_requested

var _standalone_player_data: PlayerData


func get_player_data() -> PlayerData:
	var runtime := _find_night_runtime()
	if runtime != null:
		return runtime.get_player_data()
	if _standalone_player_data == null:
		_standalone_player_data = PlayerData.new()
	return _standalone_player_data


func request_business() -> void:
	business_requested.emit()


func request_alchemy() -> void:
	alchemy_requested.emit()


func request_production() -> void:
	production_requested.emit()


func request_bedroom() -> void:
	bedroom_requested.emit()


func refresh_interaction_hints() -> void:
	for node_name: StringName in [&"Table", &"Equip", &"Transsformer"]:
		var interaction := get_node_or_null(NodePath(node_name))
		if interaction != null and interaction.has_method("refresh_hint"):
			interaction.call("refresh_hint")


func _find_night_runtime() -> Node:
	# Duck-typed: avoids compile-time class cycle with NightRuntime.
	var current := get_parent()
	while current != null:
		if current.has_method("get_player_data"):
			return current
		current = current.get_parent()
	return null
