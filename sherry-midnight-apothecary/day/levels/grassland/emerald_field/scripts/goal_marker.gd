extends Area2D

signal minigame_requested(return_position: Vector2)

var _player_inside := false
var _available := true

@onready var label: Label = get_node_or_null("Label") as Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_label()


func set_available(value: bool) -> void:
	_available = value
	_refresh_label()


func _unhandled_input(event: InputEvent) -> void:
	if not _available or not _player_inside or get_tree().has_meta("day_modal_input_locked"):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		get_viewport().set_input_as_handled()
		minigame_requested.emit(global_position)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_refresh_label()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_refresh_label()


func _refresh_label() -> void:
	if label == null:
		return
	label.visible = _available and _player_inside
	label.text = "按 [E] 启动净风仪" if _available else "翡翠原已净化"
