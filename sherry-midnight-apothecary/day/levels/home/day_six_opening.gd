class_name DaySixOpening
extends CanvasLayer

## Day-six opening presentation. Characters are intentionally represented only
## by Dialogue Manager portraits; this layer never instances world sprites.

signal opening_completed

const REQUIRED_DAY := 6
const HOME_COMPLETE_FLAG: StringName = &"day_six_apothecary_gate_complete"
const ESCORT_PENDING_FLAG: StringName = &"day_six_crownland_escort_pending"
const ESCORT_COMPLETE_FLAG: StringName = &"day_six_crownland_escort_complete"
const TASK_ID: StringName = &"crownland_invited_guest"
const DESTINATION_ID: StringName = &"crownland"
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const APOTHECARY_TEXTURE := preload("res://day/levels/home/home.png")
const CROWNLAND_HOME_SCENE := preload("res://day/levels/crownland/home.tscn")

@export var dialogue_resource: DialogueResource
@export var dialogue_title: StringName = &"start"

var _root: Control
var _background: TextureRect
var _shade: ColorRect
var _effects: Control
var _fade: ColorRect
var _caption: Label
var _gate: Panel
var _arrival_scene: Control
var _player: CharacterBody2D
var _running := false
var _completed := false
var _modal_lock_was_set := false


func _ready() -> void:
	visible = false
	_player = get_parent().get_node_or_null("Player") as CharacterBody2D
	_build_presentation()


func is_opening_active() -> bool:
	return should_present(_current_day(), _player_data())


func start() -> bool:
	if _running or _completed or not is_opening_active():
		return false
	_running = true
	visible = true
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	if _player != null:
		_player.velocity = Vector2.ZERO
		_player.visible = false
		_player.set_physics_process(false)
	var wake_reveal := get_parent().get_node_or_null("WakeReveal/FadeOverlay") as ColorRect
	if wake_reveal != null:
		wake_reveal.visible = false
	call_deferred("_run_opening")
	return true


static func should_present(current_day: int, player_data: PlayerData) -> bool:
	return current_day == REQUIRED_DAY and player_data != null \
		and not player_data.has_event_flag(HOME_COMPLETE_FLAG) \
		and not player_data.has_event_flag(ESCORT_COMPLETE_FLAG)


func _run_opening() -> void:
	_show_black_morning()
	await get_tree().create_timer(0.35).timeout
	if not _running:
		return
	await _play_dialogue()
	if not _running:
		return
	_finish_and_depart()


func _play_dialogue() -> void:
	if dialogue_resource == null:
		push_error("DaySixOpening requires a dialogue resource.")
		return
	var manager := get_node_or_null("/root/DialogueManager") as Node
	if manager == null or not manager.has_method("show_dialogue_balloon_scene"):
		push_error("DaySixOpening requires the DialogueManager autoload.")
		return
	var balloon := manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, dialogue_title) as Node
	if balloon == null:
		return
	if balloon.has_signal("dialogue_event"):
		balloon.dialogue_event.connect(_on_dialogue_event)
	await balloon.tree_exited


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	match event_name:
		&"day6_resonance":
			_flash_caption("——嗡。", Color("#dff8ff"))
			_call_sound_manager(&"play_spell_cast")
		&"day6_apothecary_reveal": _reveal_apothecary()
		&"day6_gate_reveal": _reveal_gate()
		&"day6_leyline_colors": _pulse_leyline_colors()
		&"day6_gate_pull": _play_gate_pull()
		&"day6_arrival": _show_crownland_arrival()
		&"day6_guard_steps": _flash_caption("哒。　哒。　哒。", Color("#ede7ce"))
		&"day6_invited_task": _show_task_card()


func _build_presentation() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_root.add_child(_background)
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.03, 0.04, 0.07, 0.34)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_shade)
	_effects = Control.new()
	_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_effects)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = 44.0
	_caption.offset_bottom = 98.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 27)
	_caption.modulate.a = 0.0
	_root.add_child(_caption)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_fade)
	_root.move_child(_caption, _root.get_child_count() - 1)


func _show_black_morning() -> void:
	_background.texture = null
	_shade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.visible = true
	_fade.color = Color.BLACK


func _reveal_apothecary() -> void:
	_background.texture = APOTHECARY_TEXTURE
	_shade.color = Color(0.12, 0.16, 0.24, 0.28)
	_fade.visible = true
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(_fade, "color:a", 0.0, 0.8)
	for index in range(7):
		var glint := ColorRect.new()
		glint.color = _spectrum_color(index)
		glint.position = Vector2(125.0 + index * 145.0, 330.0 + (index % 2) * 65.0)
		glint.size = Vector2(7, 34)
		glint.modulate.a = 0.0
		_effects.add_child(glint)
		var tween := create_tween().set_loops(2)
		tween.tween_property(glint, "modulate:a", 0.7, 0.35).set_delay(index * 0.05)
		tween.tween_property(glint, "modulate:a", 0.0, 0.55)
		tween.finished.connect(glint.queue_free)


func _reveal_gate() -> void:
	if is_instance_valid(_gate):
		return
	_gate = Panel.new()
	_gate.position = Vector2(446, 104)
	_gate.size = Vector2(260, 440)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.97, 1.0, 0.3)
	style.border_color = Color(0.88, 0.91, 0.78, 0.95)
	style.set_border_width_all(7)
	style.corner_radius_top_left = 125
	style.corner_radius_top_right = 125
	_gate.add_theme_stylebox_override("panel", style)
	_gate.modulate.a = 0.0
	_effects.add_child(_gate)
	var sigil := Label.new()
	sigil.text = "◇\n空与流光之馆\n✦"
	sigil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil.add_theme_font_size_override("font_size", 22)
	sigil.add_theme_color_override("font_color", Color("#ece8ce"))
	_gate.add_child(sigil)
	create_tween().tween_property(_gate, "modulate:a", 1.0, 0.8)


func _pulse_leyline_colors() -> void:
	_reveal_gate()
	for index in range(7):
		var band := ColorRect.new()
		band.color = _spectrum_color(index)
		band.position = Vector2(426 + index * 45, 92)
		band.size = Vector2(40, 464)
		band.modulate.a = 0.0
		_effects.add_child(band)
		var tween := create_tween()
		tween.tween_property(band, "modulate:a", 0.26, 0.18).set_delay(index * 0.13)
		tween.tween_property(band, "modulate:a", 0.0, 0.45)
		tween.finished.connect(band.queue_free)


func _play_gate_pull() -> void:
	_call_sound_manager(&"play_spell_release")
	if is_instance_valid(_gate):
		create_tween().set_trans(Tween.TRANS_EXPO).tween_property(_gate, "scale", Vector2(1.45, 1.12), 0.35)
	for offset in [Vector2(12, 0), Vector2(-18, 5), Vector2(25, -3), Vector2.ZERO]:
		var tween := create_tween()
		tween.tween_property(_background, "position", offset, 0.07)
	_fade.visible = true
	_fade.color = Color(1, 1, 1, 0)
	create_tween().set_trans(Tween.TRANS_EXPO).tween_property(_fade, "color:a", 1.0, 0.5)


func _show_crownland_arrival() -> void:
	_background.position = Vector2.ZERO
	_background.texture = null
	_arrival_scene = CROWNLAND_HOME_SCENE.instantiate() as Control
	if _arrival_scene != null:
		_arrival_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_effects.add_child(_arrival_scene)
		_effects.move_child(_arrival_scene, 0)
	_shade.color = Color(0.16, 0.12, 0.12, 0.12)
	if is_instance_valid(_gate):
		_gate.queue_free()
	_fade.visible = true
	_fade.color = Color(1, 1, 1, 1)
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(_fade, "color:a", 0.0, 1.0)
	for index in range(18):
		var dust := ColorRect.new()
		dust.color = Color(0.92, 0.86, 0.7, 0.35)
		dust.position = Vector2(100 + index * 61, 540 + (index % 4) * 12)
		dust.size = Vector2(5, 5)
		_effects.add_child(dust)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(dust, "position:y", dust.position.y - 90.0, 2.2 + index * 0.03)
		tween.tween_property(dust, "modulate:a", 0.0, 2.0)
		tween.chain().tween_callback(dust.queue_free)


func _show_task_card() -> void:
	_flash_caption("主线任务：受邀者　·　跟随王庭卫兵前往王宫", Color("#ede7ce"), 3.2)


func _flash_caption(text: String, color := Color.WHITE, duration := 1.4) -> void:
	_caption.text = text
	_caption.add_theme_color_override("font_color", color)
	_caption.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_caption, "modulate:a", 1.0, 0.2)
	tween.tween_interval(duration)
	tween.tween_property(_caption, "modulate:a", 0.0, 0.35)


func _finish_and_depart() -> void:
	var data := _player_data()
	if data != null:
		data.set_event_flag(HOME_COMPLETE_FLAG)
		data.set_event_flag(ESCORT_PENDING_FLAG)
		data.unlock_level(DESTINATION_ID)
		data.set_active_home_destination(DESTINATION_ID)
		data.set_active_daily_task(TASK_ID, "跟随王庭卫兵前往王宫。", REQUIRED_DAY)
		data.tutorial_flags[DayRuntime.scene_title_seen_key(REQUIRED_DAY, DESTINATION_ID)] = true
	var runtime := _find_runtime()
	if runtime != null:
		# Hand the modal lock to the Crownland escort. When this opening created
		# the lock, release it before the new scene records its own ownership.
		if not _modal_lock_was_set:
			get_tree().remove_meta("day_modal_input_locked")
		runtime.switch_to_level(str(DESTINATION_ID), &"from_home")
	_completed = true
	_running = false
	opening_completed.emit()
	if runtime == null:
		_cleanup_player()


func _cleanup_player() -> void:
	if is_instance_valid(_player):
		_player.visible = true
		_player.set_physics_process(true)
	if get_tree() != null and not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")
	visible = false


func _exit_tree() -> void:
	if _running:
		_running = false
		_cleanup_player()


func _spectrum_color(index: int) -> Color:
	return [Color("#d65d63"), Color("#d99048"), Color("#e4c64f"), Color("#68c56a"), Color("#40c7c7"), Color("#579bd8"), Color("#9f77c9")][clampi(index, 0, 6)]


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


func _call_sound_manager(method_name: StringName) -> void:
	var manager := get_node_or_null("/root/SoundManager") as Node
	if manager != null and manager.has_method(method_name):
		manager.call(method_name)
