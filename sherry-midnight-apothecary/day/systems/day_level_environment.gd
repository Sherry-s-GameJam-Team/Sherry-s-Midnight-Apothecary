class_name DayLevelEnvironment
extends Node2D

## Day-level scenes contain presentation only. DayRuntime owns progression and
## globally switches to NightRuntime after the player ends the day.

## Every daytime level exposes the same normal/corrupted state contract. A
## level may override set_corrupted() to update its own artwork.
signal environment_state_changed(corrupted: bool)

@export var debug_scene_id := ""
@export var start_corrupted := false

var _standalone_player_data: PlayerData
var _is_corrupted := false


func get_player_data() -> PlayerData:
	var host := get_parent()
	while host != null:
		if host.has_method("get_player_data"):
			return host.call("get_player_data") as PlayerData
		host = host.get_parent()
	if _standalone_player_data == null:
		_standalone_player_data = PlayerData.new()
	return _standalone_player_data


func _ready() -> void:
	_is_corrupted = start_corrupted
	var host := get_parent()
	if host != null and host.get_parent() != null and host.get_parent().has_method("get_player_data"):
		var embedded_debug_ui := get_node_or_null("DebugUI")
		if embedded_debug_ui != null:
			embedded_debug_ui.process_mode = Node.PROCESS_MODE_DISABLED
		var embedded_pause_menu_layer := get_node_or_null("PauseMenuLayer")
		if embedded_pause_menu_layer != null:
			embedded_pause_menu_layer.process_mode = Node.PROCESS_MODE_DISABLED
			var embedded_pause_menu := embedded_pause_menu_layer.get_node_or_null("PauseMenu")
			if embedded_pause_menu != null:
				embedded_pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
				embedded_pause_menu.visible = false
		return
	var console := get_node_or_null("DebugUI/DeveloperConsole")
	if console != null:
		console.setup_day_scene(self)


func set_corrupted(corrupted: bool) -> void:
	if _is_corrupted == corrupted:
		return
	_is_corrupted = corrupted
	environment_state_changed.emit(corrupted)


func is_corrupted() -> bool:
	return _is_corrupted
