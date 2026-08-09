extends Node

## Persistent one-shot SFX playback and automatic UI button feedback.

const FOOTSTEP := preload("res://audio/sfx/footsteps.ogg")
const SPELL_CAST := preload("res://audio/sfx/spell_cast.ogg")
const SPELL_RELEASE := preload("res://audio/sfx/spell_release.ogg")
const DOOR_OPEN := preload("res://audio/sfx/door_open.wav")
const DOOR_CLOSE := preload("res://audio/sfx/door_close.wav")
const UI_HOVER := preload("res://audio/sfx/ui_hover.ogg")
const UI_PRESS := preload("res://audio/sfx/ui_press.ogg")

const BUTTON_BOUND_META := &"sound_manager_bound"
const MIN_UI_HOVER_INTERVAL_MS := 45

var _last_ui_hover_ms := -MIN_UI_HOVER_INTERVAL_MS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_bind_buttons_in(get_tree().root)


func play_footstep(speed_ratio: float = 1.0) -> void:
	var speed_pitch := lerpf(0.94, 1.06, clampf(speed_ratio, 0.0, 1.0))
	_play_one_shot(FOOTSTEP, -13.0, speed_pitch * randf_range(0.94, 1.06))


func play_spell_cast() -> void:
	_play_one_shot(SPELL_CAST, -7.0, randf_range(0.97, 1.03))


func play_spell_release() -> void:
	_play_one_shot(SPELL_RELEASE, -6.0, randf_range(0.98, 1.04))


func play_door_transition() -> void:
	_play_one_shot(DOOR_OPEN, -7.0, randf_range(0.97, 1.02))
	get_tree().create_timer(0.32, true, false, true).timeout.connect(
		_play_door_close,
		CONNECT_ONE_SHOT
	)


func play_ui_press() -> void:
	_play_one_shot(UI_PRESS, -11.0, randf_range(0.98, 1.02))


func play_ui_hover() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_ui_hover_ms < MIN_UI_HOVER_INTERVAL_MS:
		return
	_last_ui_hover_ms = now
	_play_one_shot(UI_HOVER, -18.0, randf_range(1.02, 1.08))


func _play_door_close() -> void:
	_play_one_shot(DOOR_CLOSE, -8.0, randf_range(0.98, 1.03))


func _play_one_shot(stream: AudioStream, volume_db: float, pitch_scale: float) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_bind_button(node as BaseButton)


func _bind_buttons_in(node: Node) -> void:
	if node is BaseButton:
		_bind_button(node as BaseButton)
	for child in node.get_children():
		_bind_buttons_in(child)


func _bind_button(button: BaseButton) -> void:
	if button.has_meta(BUTTON_BOUND_META):
		return
	button.set_meta(BUTTON_BOUND_META, true)
	button.mouse_entered.connect(_on_button_hovered.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_hovered(button: BaseButton) -> void:
	if not button.disabled and button.is_visible_in_tree():
		play_ui_hover()


func _on_button_pressed(button: BaseButton) -> void:
	if not button.disabled:
		play_ui_press()
