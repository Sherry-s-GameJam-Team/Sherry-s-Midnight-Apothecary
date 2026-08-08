class_name AlchemyStation
extends Area2D

## Day-scene entrance to the shared alchemy interface.

@export var alchemy_scene: PackedScene
@export_node_path("Sprite2D") var visual_path: NodePath
@export var interaction_hint_text := "按[E]制药"

var visual: Sprite2D
var _outline_material: Material
var _player_is_inside := false
var _player: CharacterBody2D
var _alchemy_layer: CanvasLayer


func _ready() -> void:
	visual = get_node_or_null(visual_path) as Sprite2D if not visual_path.is_empty() else get_node_or_null("Visual") as Sprite2D
	if visual == null:
		push_error("AlchemyStation requires a Sprite2D visual.")
		return
	if alchemy_scene == null:
		push_error("AlchemyStation requires an AlchemyRuntime scene.")
		return
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_outline_material = visual.material
	_set_active(false)


func _input(event: InputEvent) -> void:
	if get_tree().has_meta("day_modal_input_locked") or not _player_is_inside or not _is_interact_event(event) or is_instance_valid(_alchemy_layer):
		return
	get_viewport().set_input_as_handled()
	_open_alchemy()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player = body
		_player_is_inside = true
		_set_active(true)
		_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_is_inside = false
		_set_active(false)
		_hide_interaction_hint()


func _open_alchemy() -> void:
	var alchemy := alchemy_scene.instantiate() as AlchemyRuntime
	if alchemy == null:
		push_error("AlchemyStation scene root must be AlchemyRuntime.")
		return
	_alchemy_layer = CanvasLayer.new()
	_alchemy_layer.name = "AlchemyInteractionLayer"
	_alchemy_layer.layer = 210
	_find_app_root().add_child(_alchemy_layer)
	alchemy.enable_standalone_console = false
	_alchemy_layer.add_child(alchemy)
	alchemy.setup(_find_player_data(), NightResult.new(), _find_day())
	alchemy.request_close.connect(_close_alchemy, CONNECT_ONE_SHOT)
	if _player != null:
		_player.set_physics_process(false)
	_hide_interaction_hint()


func _close_alchemy() -> void:
	if _player != null:
		_player.set_physics_process(true)
	if is_instance_valid(_alchemy_layer):
		_alchemy_layer.queue_free()
	_alchemy_layer = null
	if _player_is_inside:
		_show_interaction_hint()


func _set_active(active: bool) -> void:
	if visual != null:
		visual.material = _outline_material if active else null


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E)


func _find_app_root() -> Node:
	var current: Node = self
	while current != null:
		if current.get_node_or_null("GlobalUI/TopHintUI") != null:
			return current
		current = current.get_parent()
	return get_tree().root


func _find_player_data() -> PlayerData:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return PlayerData.new()


func _find_day() -> int:
	var current: Node = get_parent()
	while current != null:
		if "day" in current:
			return int(current.get("day"))
		current = current.get_parent()
	return 1


func _show_interaction_hint() -> void:
	var top_hint := _find_app_root().get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	var top_hint := _find_app_root().get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _hint_id() -> String:
	return "interaction_%s" % get_instance_id()
