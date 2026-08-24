class_name WallDialLockInteractor
extends Area2D

## Interactor on wall1 that triggers the 4-dial lock puzzle when pressing E.
## Upon unlocking (combination: 钟眼月羽):
## 1. Disables wall1 collision (CollisionPolygon2D / StaticBody2D disabled).
## 2. Changes wall1 z_index to 20 (masking/rendering above the player character).

@export var prompt_text: String = "按 E 解锁暗门"
@export var dialog_node_path: NodePath = NodePath("../../../../DialLockPuzzleDialog")

var _is_unlocked: bool = false
var _player_inside: Node2D = null

@onready var prompt_label: Label = get_node_or_null("PromptLabel")
@onready var wall1_sprite: Sprite2D = get_parent() as Sprite2D
@onready var static_body: StaticBody2D = get_node_or_null("../StaticBody2D") as StaticBody2D
@onready var collision_poly: CollisionPolygon2D = get_node_or_null("../StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D
@onready var dialog: DialLockPuzzleDialog = get_node_or_null(dialog_node_path) as DialLockPuzzleDialog


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_prompt_visible(false)

	if dialog == null:
		var root := get_tree().current_scene
		if root != null:
			dialog = root.get_node_or_null("DialLockPuzzleDialog") as DialLockPuzzleDialog

	if dialog != null:
		dialog.lock_unlocked.connect(_on_lock_unlocked)
		dialog.dialog_closed.connect(_on_dialog_closed)


func _unhandled_input(event: InputEvent) -> void:
	if _is_unlocked or _player_inside == null:
		return

	if dialog != null and dialog.visible:
		return

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		get_viewport().set_input_as_handled()
		open_lock_dialog()


func open_lock_dialog() -> void:
	if _is_unlocked:
		return

	if dialog == null:
		var root := get_tree().current_scene
		if root != null:
			dialog = root.get_node_or_null("DialLockPuzzleDialog") as DialLockPuzzleDialog
			if dialog != null and not dialog.lock_unlocked.is_connected(_on_lock_unlocked):
				dialog.lock_unlocked.connect(_on_lock_unlocked)
				dialog.dialog_closed.connect(_on_dialog_closed)

	if dialog != null:
		if _player_inside != null and _player_inside.has_method("set_control_enabled"):
			_player_inside.call("set_control_enabled", false)

		_set_prompt_visible(false)
		dialog.open_dialog()


func _on_lock_unlocked() -> void:
	_is_unlocked = true
	_set_prompt_visible(false)

	# 1. Disable wall1 collision so player can pass through freely
	if collision_poly != null:
		collision_poly.set_deferred("disabled", true)
	if static_body != null:
		static_body.collision_layer = 0
		static_body.collision_mask = 0

	# 2. Change wall1 z_index to 20 so it renders on top of the player as a foreground mask
	if wall1_sprite != null:
		wall1_sprite.z_index = 20
		wall1_sprite.z_as_relative = false

		# Subtle unlock flash effect
		var tw := create_tween()
		tw.tween_property(wall1_sprite, "modulate", Color(1.3, 1.2, 0.9, 1.0), 0.2)
		tw.tween_property(wall1_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.92), 0.3)


func _on_dialog_closed() -> void:
	if _player_inside != null and is_instance_valid(_player_inside) and _player_inside.has_method("set_control_enabled"):
		_player_inside.call("set_control_enabled", true)

	if not _is_unlocked and _player_inside != null:
		_set_prompt_visible(true)


func _on_body_entered(body: Node2D) -> void:
	if _is_unlocked:
		return
	if body.name == "Player" or body.name == "Luca" or body is CharacterBody2D:
		_player_inside = body
		_set_prompt_visible(true)


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null
		_set_prompt_visible(false)


func _set_prompt_visible(val: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = val and not _is_unlocked
		prompt_label.text = prompt_text
