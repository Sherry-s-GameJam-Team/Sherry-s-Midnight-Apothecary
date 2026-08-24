class_name CabinetLetterInteractor
extends Area2D

## Interactor for Cabinet1 that displays the 3 letters dialog when pressing E.

@export var prompt_text: String = "按 E 查看柜中信件"
@export var dialog_scene_path: NodePath = NodePath("../../LetterViewerDialog")

var _player_inside: Node2D = null

@onready var prompt_label: Label = get_node_or_null("PromptLabel")
@onready var dialog: LetterViewerDialog = get_node_or_null(dialog_scene_path)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_prompt_visible(false)

	if dialog != null:
		dialog.viewer_closed.connect(_on_dialog_closed)


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside == null:
		return

	# If dialog is currently open, let dialog handle input
	if dialog != null and dialog.visible:
		return

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		get_viewport().set_input_as_handled()
		open_letter_viewer()


func open_letter_viewer() -> void:
	if dialog == null:
		var root := get_tree().current_scene
		if root != null:
			dialog = root.get_node_or_null("LetterViewerDialog") as LetterViewerDialog
			if dialog != null and not dialog.viewer_closed.is_connected(_on_dialog_closed):
				dialog.viewer_closed.connect(_on_dialog_closed)

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
	if body.name == "Player" or body.name == "Luca" or body is CharacterBody2D:
		_player_inside = body
		_set_prompt_visible(true)


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null
		_set_prompt_visible(false)


func _set_prompt_visible(val: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = val
		prompt_label.text = prompt_text
