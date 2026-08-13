extends Node

## Persistent one-shot SFX playback and automatic UI button feedback.

const FOOTSTEP := preload("res://audio/sfx/footsteps.ogg")
const SPELL_CAST := preload("res://audio/sfx/spell_cast.ogg")
const SPELL_RELEASE := preload("res://audio/sfx/spell_release.ogg")
const DOOR_OPEN := preload("res://audio/sfx/door_open.wav")
const DOOR_CLOSE := preload("res://audio/sfx/door_close.wav")
const UI_HOVER := preload("res://audio/sfx/ui_hover.ogg")
const UI_PRESS := preload("res://audio/sfx/ui_press.ogg")
const DAY_INTERIOR_BGM := preload("res://audio/bgm/Interior_autoloop.wav")

const BUTTON_BOUND_META := &"sound_manager_bound"
const MIN_UI_HOVER_INTERVAL_MS := 45
const BGM_PLAYER_NAME := &"PersistentBGM"
const DAY_INTERIOR_BUS := &"DayInteriorBGM"
const DAY_INTERIOR_BGM_ID := &"day_interior"

const MENU_VOLUME_DB := -10.0
const ROOM_VOLUME_DB := -2.0
const MENU_REVERB_ROOM_SIZE := 0.86
const ROOM_REVERB_ROOM_SIZE := 0.36
const MENU_REVERB_DAMPING := 0.34
const ROOM_REVERB_DAMPING := 0.68
const MENU_REVERB_SPREAD := 0.92
const ROOM_REVERB_SPREAD := 0.48
const MENU_REVERB_WET := 0.28
const ROOM_REVERB_WET := 0.12
const MENU_REVERB_DRY := 0.72
const ROOM_REVERB_DRY := 0.88
const MENU_STEREO_WIDTH := 1.35
const ROOM_STEREO_WIDTH := 1.0
const MENU_LOW_PASS_HZ := 7600.0
const ROOM_LOW_PASS_HZ := 14500.0

const REVERB_EFFECT_INDEX := 0
const STEREO_EFFECT_INDEX := 1
const LOW_PASS_EFFECT_INDEX := 2

var _last_ui_hover_ms := -MIN_UI_HOVER_INTERVAL_MS
var _bgm_player: AudioStreamPlayer
var _current_bgm := &""
var _day_interior_bus_index := -1
var _day_interior_reverb: AudioEffectReverb
var _day_interior_stereo: AudioEffectStereoEnhance
var _day_interior_low_pass: AudioEffectLowPassFilter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_bind_buttons_in(get_tree().root)


func play_footstep(speed_ratio: float = 1.0) -> void:
	var speed_pitch := lerpf(0.94, 1.06, clampf(speed_ratio, 0.0, 1.0))
	_play_one_shot(FOOTSTEP, -10.0, speed_pitch * randf_range(0.94, 1.06), &"SFX")


func play_spell_cast() -> void:
	_play_one_shot(SPELL_CAST, -7.0, randf_range(0.97, 1.03), &"SFX")


func play_spell_release() -> void:
	_play_one_shot(SPELL_RELEASE, -6.0, randf_range(0.98, 1.04), &"SFX")


func play_door_transition() -> void:
	_play_one_shot(DOOR_OPEN, -7.0, randf_range(0.97, 1.02), &"SFX")
	get_tree().create_timer(0.32, true, false, true).timeout.connect(
		_play_door_close,
		CONNECT_ONE_SHOT
	)


func play_ui_press() -> void:
	_play_one_shot(UI_PRESS, -11.0, randf_range(0.98, 1.02), &"UI")


func play_ui_hover() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_ui_hover_ms < MIN_UI_HOVER_INTERVAL_MS:
		return
	_last_ui_hover_ms = now
	_play_one_shot(UI_HOVER, -15.0, randf_range(1.02, 1.08), &"UI")


func play_day_interior_bgm() -> void:
	_ensure_day_interior_bus()
	var player := _get_bgm_player()
	if _current_bgm == DAY_INTERIOR_BGM_ID and player.playing:
		return
	var looping_stream := DAY_INTERIOR_BGM.duplicate() as AudioStreamWAV
	looping_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looping_stream.loop_begin = 0
	looping_stream.loop_end = int(round(looping_stream.get_length() * looping_stream.mix_rate))
	player.stream = looping_stream
	_current_bgm = DAY_INTERIOR_BGM_ID
	player.play()


func set_day_interior_transition(progress: float) -> void:
	_ensure_day_interior_bus()
	var blend := _day_interior_profile_blend(progress)
	AudioServer.set_bus_volume_db(_day_interior_bus_index, lerpf(MENU_VOLUME_DB, ROOM_VOLUME_DB, blend))
	_day_interior_reverb.room_size = lerpf(MENU_REVERB_ROOM_SIZE, ROOM_REVERB_ROOM_SIZE, blend)
	_day_interior_reverb.damping = lerpf(MENU_REVERB_DAMPING, ROOM_REVERB_DAMPING, blend)
	_day_interior_reverb.spread = lerpf(MENU_REVERB_SPREAD, ROOM_REVERB_SPREAD, blend)
	_day_interior_reverb.wet = lerpf(MENU_REVERB_WET, ROOM_REVERB_WET, blend)
	_day_interior_reverb.dry = lerpf(MENU_REVERB_DRY, ROOM_REVERB_DRY, blend)
	_day_interior_stereo.pan_pullout = lerpf(MENU_STEREO_WIDTH, ROOM_STEREO_WIDTH, blend)
	_day_interior_low_pass.cutoff_hz = lerpf(MENU_LOW_PASS_HZ, ROOM_LOW_PASS_HZ, blend)


func set_day_interior_menu_profile() -> void:
	set_day_interior_transition(0.0)


func set_day_interior_room_profile() -> void:
	set_day_interior_transition(1.0)


func stop_bgm() -> void:
	if is_instance_valid(_bgm_player):
		_bgm_player.stop()
	_current_bgm = &""


func _play_door_close() -> void:
	_play_one_shot(DOOR_CLOSE, -8.0, randf_range(0.98, 1.03), &"SFX")


func _play_one_shot(stream: AudioStream, volume_db: float, pitch_scale: float, bus_name: StringName) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = bus_name
	add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()


func _get_bgm_player() -> AudioStreamPlayer:
	if is_instance_valid(_bgm_player):
		return _bgm_player
	_bgm_player = get_node_or_null(NodePath(str(BGM_PLAYER_NAME))) as AudioStreamPlayer
	if _bgm_player == null:
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.name = BGM_PLAYER_NAME
		_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_bgm_player)
	_bgm_player.bus = DAY_INTERIOR_BUS
	return _bgm_player


func _ensure_day_interior_bus() -> void:
	_day_interior_bus_index = AudioServer.get_bus_index(DAY_INTERIOR_BUS)
	if _day_interior_bus_index < 0:
		AudioServer.add_bus()
		_day_interior_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_day_interior_bus_index, DAY_INTERIOR_BUS)
	AudioServer.set_bus_send(_day_interior_bus_index, &"Music")
	if (
		is_instance_valid(_day_interior_reverb)
		and is_instance_valid(_day_interior_stereo)
		and is_instance_valid(_day_interior_low_pass)
		and AudioServer.get_bus_effect_count(_day_interior_bus_index) == 3
		and AudioServer.get_bus_effect(_day_interior_bus_index, REVERB_EFFECT_INDEX) == _day_interior_reverb
		and AudioServer.get_bus_effect(_day_interior_bus_index, STEREO_EFFECT_INDEX) == _day_interior_stereo
		and AudioServer.get_bus_effect(_day_interior_bus_index, LOW_PASS_EFFECT_INDEX) == _day_interior_low_pass
	):
		return
	while AudioServer.get_bus_effect_count(_day_interior_bus_index) > 0:
		AudioServer.remove_bus_effect(_day_interior_bus_index, 0)
	_day_interior_reverb = AudioEffectReverb.new()
	_day_interior_stereo = AudioEffectStereoEnhance.new()
	_day_interior_low_pass = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(_day_interior_bus_index, _day_interior_reverb, REVERB_EFFECT_INDEX)
	AudioServer.add_bus_effect(_day_interior_bus_index, _day_interior_stereo, STEREO_EFFECT_INDEX)
	AudioServer.add_bus_effect(_day_interior_bus_index, _day_interior_low_pass, LOW_PASS_EFFECT_INDEX)


static func _day_interior_profile_blend(progress: float) -> float:
	var path_progress := clampf(progress, 0.0, 1.0)
	if path_progress <= 0.2:
		return smoothstep(0.0, 0.2, path_progress) * 0.12
	if path_progress <= 0.63:
		return lerpf(0.12, 0.58, smoothstep(0.2, 0.63, path_progress))
	return lerpf(0.58, 1.0, smoothstep(0.63, 1.0, path_progress))


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
