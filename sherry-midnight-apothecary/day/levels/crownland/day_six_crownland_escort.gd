class_name DaySixCrownlandEscort
extends CanvasLayer

## Camera-led Day 6 escort. The actual Player stays hidden while its camera is
## moved to the cathedral marker; no party or guard world sprites are spawned.

signal escort_completed

const REQUIRED_DAY := 6
const PENDING_FLAG: StringName = &"day_six_crownland_escort_pending"
const COMPLETE_FLAG: StringName = &"day_six_crownland_escort_complete"
const TASK_ID: StringName = &"crownland_invited_guest"
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var dialogue_resource: DialogueResource
@export var dialogue_title: StringName = &"start"
@export_range(1.0, 60.0, 0.5) var camera_travel_seconds := 22.0

@onready var _player := get_node_or_null("../Player") as CharacterBody2D
@onready var _cathedral := get_node_or_null("../EntryPoints/cathedral") as Marker2D
@onready var _enzuo := get_node_or_null("../DaySixParty/Enzuo") as AnimatedSprite2D
@onready var _luca := get_node_or_null("../DaySixParty/Luca") as LucaPlayer

var _root: Control
var _letterbox_top: ColorRect
var _letterbox_bottom: ColorRect
var _veil: ColorRect
var _caption: Label
var _running := false
var _completed := false
var _movement_tween: Tween
var _modal_lock_was_set := false


func _ready() -> void:
	visible = false
	_build_overlay()
	var keep_enzuo := _current_day() == REQUIRED_DAY and _player_data() != null and _player_data().has_event_flag(COMPLETE_FLAG)
	if _enzuo != null:
		_enzuo.visible = keep_enzuo
		_enzuo.play(&"idle")
	if _luca != null:
		_luca.visible = false
		_luca.input_enabled = false
		_luca.stop_moving()


func begin_for_entry(entry_id: StringName) -> void:
	if String(entry_id) not in ["", "default", "from_home"] or not should_present(_current_day(), _player_data()):
		return
	call_deferred("_begin_sequence")


static func should_present(current_day: int, player_data: PlayerData) -> bool:
	return current_day == REQUIRED_DAY and player_data != null \
		and player_data.has_event_flag(PENDING_FLAG) \
		and not player_data.has_event_flag(COMPLETE_FLAG)


func _begin_sequence() -> void:
	if _running or _completed or _player == null or _cathedral == null:
		return
	_running = true
	visible = true
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	_player.velocity = Vector2.ZERO
	_player.visible = true
	_player.set_physics_process(false)
	if _player.has_method("set_dialogue_locked"):
		_player.call("set_dialogue_locked", true)
	if _player.has_method("set_potion_action_locked"):
		_player.call("set_potion_action_locked", true)
	_player.call("_update_facing", 1.0)
	_player.call("_play", "walk")
	_enzuo.visible = true
	_enzuo.global_position = _player.global_position + Vector2(-82.0, 0.0)
	_enzuo.play(&"walk")
	_luca.visible = true
	_luca.global_position = _player.global_position + Vector2(-175.0, 6.0)
	_luca.set_physics_process(false)
	_luca.set_movement_direction(1.0)
	_start_camera_march()
	await _play_dialogue()
	if _running:
		_finish_sequence()


func _start_camera_march() -> void:
	_caption.text = "王都巡行 · 前往王宫"
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 0.72, 0.5)
	_movement_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_movement_tween.tween_property(_player, "global_position", _cathedral.global_position, camera_travel_seconds)
	_movement_tween.tween_property(_enzuo, "global_position", _cathedral.global_position + Vector2(-82.0, 0.0), camera_travel_seconds)
	_movement_tween.tween_property(_luca, "global_position", _cathedral.global_position + Vector2(-175.0, 6.0), camera_travel_seconds)


func _play_dialogue() -> void:
	if dialogue_resource == null:
		push_error("DaySixCrownlandEscort requires a dialogue resource.")
		return
	var manager := get_node_or_null("/root/DialogueManager") as Node
	if manager == null or not manager.has_method("show_dialogue_balloon_scene"):
		push_error("DaySixCrownlandEscort requires the DialogueManager autoload.")
		return
	var balloon := manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, dialogue_title) as Node
	if balloon == null:
		return
	if balloon.has_signal("dialogue_event"):
		balloon.dialogue_event.connect(_on_dialogue_event)
	await balloon.tree_exited


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	match event_name:
		&"day6_memory_king": _memory_flash("王座之间 · 黑色脉络沿王座攀升")
		&"day6_memory_pillars": _memory_flash("王座之后 · 地下黑柱连接着仪式核心")
		&"day6_cathedral_arrival": _freeze_at_cathedral()
		&"day6_serena_scent": _play_underground_wind()
		&"day6_luca_departure": _play_luca_departure()
		&"day6_return_to_party": _return_to_party_view()


func _freeze_at_cathedral() -> void:
	if _movement_tween != null and _movement_tween.is_valid():
		_movement_tween.kill()
	_player.global_position = _cathedral.global_position
	_player.call("_play", "idle")
	_enzuo.global_position = _cathedral.global_position + Vector2(-82.0, 0.0)
	_enzuo.play(&"idle")
	_luca.global_position = _cathedral.global_position + Vector2(-175.0, 6.0)
	_luca.stop_moving()
	_caption.text = "圣堂前 · 地下风道"
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.9, 0.94, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.32, 0.12)
	tween.tween_property(flash, "color:a", 0.0, 0.35)
	tween.tween_callback(flash.queue_free)


func _memory_flash(text: String) -> void:
	var card := ColorRect.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.color = Color(0.015, 0.01, 0.025, 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(card)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color("#b9a6c8"))
	card.add_child(label)
	var tween := create_tween()
	tween.tween_property(card, "color:a", 0.86, 0.18)
	tween.tween_interval(0.8)
	tween.tween_property(card, "color:a", 0.0, 0.45)
	tween.tween_callback(card.queue_free)


func _play_underground_wind() -> void:
	_caption.text = "地下通风口吹来月盐、灰铃草与苦艾的气味"
	_caption.add_theme_color_override("font_color", Color("#c9c1e8"))
	var tween := create_tween()
	tween.tween_property(_veil, "color:a", 0.18, 0.5)
	tween.tween_property(_veil, "color:a", 0.04, 1.1)


func _play_luca_departure() -> void:
	_caption.text = "石柱阴影掠过排水检修口 · 无人察觉卢卡离队"
	_veil.color = Color(0.02, 0.015, 0.04, 0.04)
	var tween := create_tween()
	tween.tween_property(_veil, "color:a", 0.72, 0.35)
	tween.parallel().tween_property(_luca, "position", _luca.position + Vector2(-95.0, 28.0), 0.55)
	tween.parallel().tween_property(_luca, "modulate:a", 0.0, 0.55)
	tween.tween_interval(0.5)
	tween.tween_property(_veil, "color:a", 0.08, 0.55)
	tween.tween_callback(func(): _luca.visible = false)


func _return_to_party_view() -> void:
	_caption.text = "王座之间长廊"
	create_tween().tween_property(_veil, "color:a", 0.0, 0.45)


func _build_overlay() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.05, 0.04, 0.08, 0.04)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_veil)
	_letterbox_top = ColorRect.new()
	_letterbox_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_letterbox_top.offset_bottom = 34.0
	_letterbox_top.color = Color.BLACK
	_root.add_child(_letterbox_top)
	_letterbox_bottom = ColorRect.new()
	_letterbox_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_letterbox_bottom.offset_top = -34.0
	_letterbox_bottom.color = Color.BLACK
	_root.add_child(_letterbox_bottom)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = 40.0
	_caption.offset_bottom = 78.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 20)
	_caption.add_theme_color_override("font_color", Color("#ede7ce"))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_caption)


func _finish_sequence() -> void:
	_running = false
	_completed = true
	_freeze_at_cathedral()
	var data := _player_data()
	if data != null:
		data.set_event_flag(COMPLETE_FLAG)
		data.clear_event_flag(PENDING_FLAG)
		data.set_active_daily_task(TASK_ID, "进入王宫，查明国王与黑柱仪式的真相。", REQUIRED_DAY)
	if is_instance_valid(_player):
		_player.visible = true
		_player.set_physics_process(true)
		if _player.has_method("set_dialogue_locked"):
			_player.call("set_dialogue_locked", false)
		if _player.has_method("set_potion_action_locked"):
			_player.call("set_potion_action_locked", false)
	if is_instance_valid(_enzuo):
		_enzuo.visible = true
		_enzuo.play(&"idle")
	if is_instance_valid(_luca):
		_luca.visible = false
		_luca.set_physics_process(true)
	if not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")
	visible = false
	escort_completed.emit()


func _exit_tree() -> void:
	if _running and not _modal_lock_was_set and get_tree() != null:
		get_tree().remove_meta("day_modal_input_locked")


func _current_day() -> int:
	var runtime := _find_runtime()
	return runtime.day if runtime != null else -1


func _player_data() -> PlayerData:
	var runtime := _find_runtime()
	return runtime.get_player_data() if runtime != null else null


func _find_runtime() -> DayRuntime:
	var current := get_parent()
	while current != null:
		if current is DayRuntime:
			return current as DayRuntime
		current = current.get_parent()
	return null
