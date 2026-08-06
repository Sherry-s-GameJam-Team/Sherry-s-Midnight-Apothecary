class_name DayLevelEnvironment
extends Node2D

## Day-level scenes contain presentation only. DayRuntime owns progression and
## globally switches to NightRuntime after the player ends the day.

@export var debug_scene_id := ""
@export var debug_location_name := ""
@export var debug_disaster_name := "灾难未定"
@export_multiline var debug_scene_description := "场景描述待补充"

var _standalone_player_data: PlayerData


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
	var host := get_parent()
	if host != null and host.get_parent() != null and host.get_parent().has_method("get_player_data"):
		var embedded_debug_ui := get_node_or_null("DebugUI")
		if embedded_debug_ui != null:
			embedded_debug_ui.process_mode = Node.PROCESS_MODE_DISABLED
		return
	var console := get_node_or_null("DebugUI/DeveloperConsole")
	if console != null:
		console.setup_day_scene(self)


func replay_scene_title() -> void:
	var title_card := get_node_or_null("SceneTitleCard")
	if title_card == null:
		return
	title_card.show_title(
		1,
		debug_location_name if not debug_location_name.is_empty() else name,
		debug_disaster_name,
		debug_scene_description
	)
