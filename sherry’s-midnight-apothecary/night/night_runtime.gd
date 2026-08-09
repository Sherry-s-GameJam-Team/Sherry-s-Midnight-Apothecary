class_name NightRuntime
extends Node

signal finished(result: NightResult)

var player_data: PlayerData
var day := 1
var current_night_result := NightResult.new()
var _standalone_player_data: PlayerData

@onready var shop_slot: Node2D = $ShopSlot
@onready var night_home: NightHome = $ShopSlot/NightHome
@onready var customer_slot: Node2D = $CustomerSlot
@onready var business_placeholder: BusinessPlaceholder = $CustomerSlot/BusinessPlaceholder
@onready var alchemy_slot: Node2D = $AlchemySlot
@onready var alchemy_runtime: AlchemyRuntime = $AlchemySlot/AlchemyRuntime
@onready var developer_console: DeveloperConsole = $UI/DeveloperConsole


func _ready() -> void:
	_show_shop()
	developer_console.setup(self)


func get_player_data() -> PlayerData:
	if player_data != null:
		return player_data
	if _standalone_player_data == null:
		_standalone_player_data = PlayerData.new()
	return _standalone_player_data


func configure(shared_player_data: PlayerData, current_day: int) -> void:
	player_data = shared_player_data
	day = current_day
	current_night_result = NightResult.new()
	_resolve_scene_nodes()
	if night_home == null:
		push_error("NightRuntime is missing its NightHome scene.")
		return
	_place_player_at_default()
	_show_shop()
	var alchemy := get_node_or_null("AlchemySlot/AlchemyRuntime") as AlchemyRuntime
	if alchemy == null:
		push_error("NightRuntime is missing its AlchemyRuntime scene.")
		return
	alchemy_runtime = alchemy
	alchemy_runtime.setup(player_data, current_night_result, day)
	var console := get_node_or_null("UI/DeveloperConsole") as DeveloperConsole
	if console == null:
		push_error("NightRuntime is missing its DeveloperConsole scene.")
		return
	developer_console = console
	developer_console.setup(self)


func open_business() -> void:
	_resolve_scene_nodes()
	if shop_slot == null or customer_slot == null:
		return
	_clear_interaction_hints()
	_set_player_enabled(false)
	shop_slot.hide()
	shop_slot.process_mode = Node.PROCESS_MODE_DISABLED
	customer_slot.process_mode = Node.PROCESS_MODE_INHERIT
	customer_slot.show()


func return_to_shop() -> void:
	_resolve_scene_nodes()
	if shop_slot == null or customer_slot == null:
		return
	customer_slot.hide()
	customer_slot.process_mode = Node.PROCESS_MODE_DISABLED
	shop_slot.process_mode = Node.PROCESS_MODE_INHERIT
	shop_slot.show()
	_set_player_enabled(true)
	if night_home != null:
		night_home.call_deferred("refresh_interaction_hints")


func open_alchemy() -> void:
	_resolve_scene_nodes()
	if shop_slot == null or alchemy_slot == null or alchemy_runtime == null:
		return
	_clear_interaction_hints()
	_set_player_enabled(false)
	shop_slot.hide()
	shop_slot.process_mode = Node.PROCESS_MODE_DISABLED
	alchemy_slot.process_mode = Node.PROCESS_MODE_INHERIT
	alchemy_slot.show()


func open_production() -> void:
	open_alchemy()
	if alchemy_slot != null and alchemy_slot.visible and alchemy_runtime != null:
		alchemy_runtime.show_production_panel()


func finish_night(result: NightResult = null) -> void:
	var final_result := result if result != null else current_night_result
	if final_result != null:
		finished.emit(final_result)


func _on_alchemy_request_close() -> void:
	finish_night()


func _on_business_requested() -> void:
	open_business()


func _on_alchemy_requested() -> void:
	open_alchemy()


func _on_production_requested() -> void:
	open_production()


func _on_business_request_return() -> void:
	return_to_shop()


func _show_shop() -> void:
	_resolve_scene_nodes()
	if shop_slot != null:
		shop_slot.process_mode = Node.PROCESS_MODE_INHERIT
		shop_slot.show()
	if customer_slot != null:
		customer_slot.hide()
		customer_slot.process_mode = Node.PROCESS_MODE_DISABLED
	if alchemy_slot != null:
		alchemy_slot.hide()
		alchemy_slot.process_mode = Node.PROCESS_MODE_DISABLED
	_set_player_enabled(true)


func _resolve_scene_nodes() -> void:
	shop_slot = get_node_or_null("ShopSlot") as Node2D
	night_home = get_node_or_null("ShopSlot/NightHome") as NightHome
	customer_slot = get_node_or_null("CustomerSlot") as Node2D
	business_placeholder = get_node_or_null("CustomerSlot/BusinessPlaceholder") as BusinessPlaceholder
	alchemy_slot = get_node_or_null("AlchemySlot") as Node2D
	alchemy_runtime = get_node_or_null("AlchemySlot/AlchemyRuntime") as AlchemyRuntime


func _place_player_at_default() -> void:
	if night_home == null:
		return
	var player := night_home.get_node_or_null("Player") as CharacterBody2D
	var entry := night_home.get_node_or_null("EntryPoints/default") as Marker2D
	if player != null and entry != null:
		player.global_position = entry.global_position


func _set_player_enabled(enabled: bool) -> void:
	if night_home == null:
		return
	var player := night_home.get_node_or_null("Player") as CharacterBody2D
	if player != null:
		player.set_physics_process(enabled)


func _clear_interaction_hints() -> void:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			top_hint.clear_all()
			return
		current = current.get_parent()
