class_name NightStationInteraction
extends Area2D

enum Action {
	MESSAGE,
	BUSINESS,
	ALCHEMY,
}

@export var action := Action.MESSAGE
@export var interaction_hint_text := "按[E]互动"
@export_multiline var pressed_message := ""
@export var message_auto_hide_seconds := 3.0
@export_node_path("Sprite2D") var visual_path: NodePath

var _visual: Sprite2D
var _outline_material: Material
var _player_inside := false


func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Sprite2D if not visual_path.is_empty() else get_node_or_null("Visual") as Sprite2D
	if _visual == null:
		push_error("NightStationInteraction requires a Sprite2D visual.")
		return
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_outline_material = _visual.material
	_set_active(false)


func _input(event: InputEvent) -> void:
	if not _player_inside or not _is_interact_event(event):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	_hide_interaction_hint()
	match action:
		Action.MESSAGE:
			_show_pressed_message()
		Action.BUSINESS:
			var home := _find_night_home()
			if home != null:
				home.request_business()
		Action.ALCHEMY:
			var home := _find_night_home()
			if home != null:
				home.request_alchemy()


func refresh_hint() -> void:
	if _player_inside:
		_show_interaction_hint()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player_inside = true
		_set_active(true)
		_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player_inside = false
		_set_active(false)
		_hide_interaction_hint()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _set_active(active: bool) -> void:
	if _visual != null:
		_visual.material = _outline_material if active else null


func _show_pressed_message() -> void:
	if pressed_message.is_empty():
		return
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.push_text(pressed_message, "%s_message" % _hint_id(), message_auto_hide_seconds)


func _show_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _find_night_home() -> NightHome:
	var current := get_parent()
	while current != null:
		if current is NightHome:
			return current as NightHome
		current = current.get_parent()
	return null


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return null


func _hint_id() -> String:
	return "interaction_%s" % get_instance_id()
