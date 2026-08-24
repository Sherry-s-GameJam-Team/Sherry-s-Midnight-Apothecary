class_name CabinetLetterInteractor
extends Area2D

## Interactor for Cabinet1 that displays the 3 letters dialog when pressing E.

@export var prompt_text: String = "按 E 查看信件"
@export var dialog_scene_path: NodePath = NodePath("../../LetterViewerDialog")

var _player_inside: Node2D = null

@onready var prompt_label: Label = get_node_or_null("PromptLabel")
@onready var dialog: LetterViewerDialog = get_node_or_null(dialog_scene_path)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2 | 3
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_prompt_visible(false)

	_resolve_dialog()


func _resolve_dialog() -> void:
	if dialog == null:
		var root := get_tree().current_scene
		if root != null:
			dialog = root.find_child("LetterViewerDialog", true, false) as LetterViewerDialog
	if dialog != null and not dialog.viewer_closed.is_connected(_on_dialog_closed):
		dialog.viewer_closed.connect(_on_dialog_closed)


func _input(event: InputEvent) -> void:
	if get_tree().has_meta("day_modal_input_locked"):
		return

	if _player_inside == null:
		# Fallback: check overlapping bodies
		for b in get_overlapping_bodies():
			if _is_player(b):
				_player_inside = b
				_set_prompt_visible(true)
				break
		if _player_inside == null:
			return

	# If dialog is currently open, let dialog handle input
	if dialog != null and dialog.visible:
		return

	if _is_interact_event(event):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		open_letter_viewer()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E or key_event.key_label == KEY_E
	)


func open_letter_viewer() -> void:
	_resolve_dialog()

	if dialog != null:
		# Lock player movement while reading
		if _player_inside != null and _player_inside.has_method("set_control_enabled"):
			_player_inside.call("set_control_enabled", false)

		_set_prompt_visible(false)
		dialog.open_viewer()


func _on_dialog_closed() -> void:
	# Restore player movement
	if _player_inside != null and is_instance_valid(_player_inside) and _player_inside.has_method("set_control_enabled"):
		_player_inside.call("set_control_enabled", true)

	if _player_inside != null:
		_set_prompt_visible(true)


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_inside = body
		_set_prompt_visible(true)


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null
		_set_prompt_visible(false)


func _is_player(body: Node) -> bool:
	if body == null:
		return false
	return body.name == "Player" or body.name == "Luca" or body.is_in_group("player") or body is CharacterBody2D


func _set_prompt_visible(val: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = val
		prompt_label.text = prompt_text
