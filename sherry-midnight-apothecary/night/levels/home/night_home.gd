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


func get_remaining_customer_count() -> int:
	var runtime := _find_night_runtime()
	if runtime != null and runtime.has_method("get_remaining_customer_count"):
		return runtime.get_remaining_customer_count()
	return 0


func get_completed_customer_count() -> int:
	var runtime := _find_night_runtime()
	if runtime != null and runtime.has_method("get_completed_customer_count"):
		return runtime.get_completed_customer_count()
	return 0


func configure_for_day(current_day: int) -> void:
	var luca := get_node_or_null("LucaNightNPC")
	if luca != null and luca.has_method("configure_for_day"):
		luca.call("configure_for_day", current_day)
	var enzuo := get_node_or_null("issue/Day1/EnzuoNightNPC")
	if enzuo != null and enzuo.has_method("configure_for_day"):
		enzuo.call("configure_for_day", current_day)


func has_operated() -> bool:
	var runtime := _find_night_runtime()
	if runtime != null and runtime.has_method("has_operated"):
		return runtime.has_operated()
	return false


func request_business() -> void:
	business_requested.emit()


func request_alchemy() -> void:
	alchemy_requested.emit()


func request_production() -> void:
	production_requested.emit()


func request_bedroom() -> void:
	bedroom_requested.emit()


func refresh_interaction_hints() -> void:
	for node_name: StringName in [&"Table", &"Equip"]:
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
