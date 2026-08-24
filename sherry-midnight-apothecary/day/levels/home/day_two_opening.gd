class_name DayTwoOpening
extends CanvasLayer

## Day-two visual-novel opening. The bedroom owns the presentation while
## DayRuntime and PlayerData remain the source of truth for day/task state.

signal opening_completed

const REQUIRED_DAY := 2
const COMPLETE_FLAG: StringName = &"day_two_opening_complete"
const SUPPLY_FLAG: StringName = &"enzo_remote_supply_unlocked"
const CYAN_RECIPE_FLAG: StringName = &"cyan_surge_potion_unlocked"
const TASK_ID: StringName = &"deliver_cyan_surge_potions"
const DESTINATION_ID: StringName = &"golden_cliff"
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const SpringburstProgression := preload("res://day/levels/lake_bottom/scripts/springburst_potion_progression.gd")
const BEDROOM_TEXTURE := preload("res://day/levels/home/player_bedroom.png")
const HOME_TEXTURE := preload("res://day/levels/home/home.png")

@export var dialogue_resource: DialogueResource
@export var dialogue_title: StringName = &"start"

var _root: Control
var _stage: Control
var _background: TextureRect
var _letter: PanelContainer
var _letter_text: RichTextLabel
var _effect_layer: Control
var _tutorial: PanelContainer
var _tutorial_text: RichTextLabel
var _fade: ColorRect
var _caption: Label
var _player: CharacterBody2D
var _balloon: Node
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
	return current_day == REQUIRED_DAY and player_data != null and not player_data.has_event_flag(COMPLETE_FLAG)


func _run_opening() -> void:
	_show_black_morning()
	await get_tree().create_timer(0.45).timeout
	if not _running:
		return
	await _play_dialogue()
	if not _running:
		return
	await _play_white_transition()
	_finish_and_depart()


func _play_dialogue() -> void:
	if dialogue_resource == null:
		push_error("DayTwoOpening requires a dialogue resource.")
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager") as Node
	if dialogue_manager == null or not dialogue_manager.has_method("show_dialogue_balloon_scene"):
		push_error("DayTwoOpening requires the DialogueManager autoload.")
		return
	_balloon = dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, dialogue_title)
	if _balloon == null:
		return
	if _balloon.has_signal("dialogue_event"):
		_balloon.dialogue_event.connect(_on_dialogue_event)
	await _balloon.tree_exited
	_balloon = null


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	match event_name:
		&"day2_scratch": _play_scratch_effect()
		&"day2_bed_thump":
			_shake_stage(10.0)
			_flash_caption("砰！")
		&"day2_time_skip": _flash_caption("更衣中 ···")
		&"day2_doorway": _show_doorway_scene()
		&"day2_letter": _show_letter_closeup()
		&"day2_letter_hide": _hide_letter()
		&"day2_downstairs": _show_downstairs_scene()
		&"day2_green_check": _highlight_potion(Color("#68c56a"), -92.0)
		&"day2_blue_check": _highlight_potion(Color("#579bd8"), -34.0)
		&"day2_supply_magic": _play_supply_magic()
		&"day2_supply_tutorial": _show_tutorial(
			"[center][color=#e8bc65][font_size=28]新功能解锁[/font_size][/color]\n[font_size=34]恩佐的远程补给[/font_size][/center]\n\n从烁金横崖开始，恩佐会缓慢补充雪莉已登记的基础投掷药水。\n\n快捷栏与背包内出现过的基础药水都可补充。\n\n[color=#d7ae46]此前区域、药典屋以及特殊与未掌握配方不参与自动补充。[/color]"
		)
		&"day2_cyan_setup": _hide_tutorial()
		&"day2_mixing_tutorial": _play_color_mixing()
		&"day2_cyan_success": _play_cyan_success()
		&"day2_recipe_tutorial": _show_tutorial(
			"[center][color=#42caca][font_size=28]新配方获得[/font_size][/color]\n[font_size=34]青色 · 涌水药水[/font_size][/center]\n\n主药理：调衡 / 稳流\n\n短时间汇聚水分与魔力，制造强烈涌水。"
		)
		&"day2_throw_tutorial": _show_tutorial(
			"[center][color=#e8bc65][font_size=30]远程药水效果[/font_size][/color][/center]\n\n投掷药水破碎后会释放区域药效。\n\n[color=#68c56a]绿色：恢复与再生[/color]　[color=#579bd8]蓝色：净化污染[/color]\n[color=#e4c64f]黄色：缓冲冲击[/color]　[color=#40c7c7]青色：稳定水流、温度与魔力[/color]\n[color=#d65d63]红色：生命压力与冲击[/color]　[color=#d99048]橙色：活化行动与机械[/color]\n[color=#9f77c9]紫色：镇静精神干扰[/color]\n\n[color=#d7ae46]委托用涌水药水暂存于剧情道具栏，目前无法装备或投掷。[/color]"
		)
		&"day2_pack": _play_pack_effect()
		&"day2_morning_light": _play_morning_light()


func _build_presentation() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_stage)
	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_stage.add_child(_background)
	var warm := ColorRect.new()
	warm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warm.color = Color(1.0, 0.76, 0.42, 0.08)
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(warm)
	_effect_layer = Control.new()
	_effect_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_effect_layer)
	_build_letter()
	_build_tutorial()
	_caption = Label.new()
	_caption.position = Vector2(0, 54)
	_caption.size = Vector2(1152, 50)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color("#eadcbf"))
	_caption.modulate.a = 0.0
	_root.add_child(_caption)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_fade)
	# Captions belong above the blackout/whiteout while dialogue remains on the
	# global layer 100 balloon.
	_root.move_child(_caption, _root.get_child_count() - 1)


func _make_character(texture: Texture2D, at: Vector2, size: Vector2) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = texture
	portrait.position = at
	portrait.size = size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.visible = false
	return portrait


func _build_letter() -> void:
	_letter = PanelContainer.new()
	_letter.position = Vector2(296, 58)
	_letter.size = Vector2(560, 500)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#efe0b9")
	style.border_color = Color("#73532e")
	style.set_border_width_all(4)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 14
	_letter.add_theme_stylebox_override("panel", style)
	_letter_text = RichTextLabel.new()
	_letter_text.bbcode_enabled = true
	_letter_text.fit_content = true
	_letter_text.add_theme_color_override("default_color", Color("#382c22"))
	_letter_text.add_theme_font_size_override("normal_font_size", 20)
	_letter_text.text = "[center][font_size=27]药典屋的雪莉小姐[/font_size][/center]\n\n咱叫卡琳娜·喵斯，是涟汀村的大司鱼……暂代的。\n\n咱想订几瓶[color=#168f93]青色的涌水药水[/color]，越能出水越好。\n\n沿常霁云林树冠往北，过烁金横崖便能看见涟汀村。\n\n急用。真的挺急的。\n\n[right]——卡琳娜·喵斯　　><(((°>[/right]"
	_letter.add_child(_letter_text)
	_letter.visible = false
	_stage.add_child(_letter)


func _build_tutorial() -> void:
	_tutorial = PanelContainer.new()
	_tutorial.position = Vector2(226, 92)
	_tutorial.size = Vector2(700, 430)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.08, 0.97)
	style.border_color = Color("#b9944f")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.58)
	style.shadow_size = 18
	_tutorial.add_theme_stylebox_override("panel", style)
	_tutorial_text = RichTextLabel.new()
	_tutorial_text.bbcode_enabled = true
	_tutorial_text.fit_content = true
	_tutorial_text.add_theme_color_override("default_color", Color("#eadfc8"))
	_tutorial_text.add_theme_font_size_override("normal_font_size", 21)
	_tutorial.add_child(_tutorial_text)
	_tutorial.visible = false
	_stage.add_child(_tutorial)


func _show_black_morning() -> void:
	_background.texture = BEDROOM_TEXTURE
	_fade.visible = true
	_fade.color = Color.BLACK
	_flash_caption("第二日 · 清晨\n窗外传来鸟鸣，楼下玻璃瓶轻轻相碰")


func _show_doorway_scene() -> void:
	_background.texture = BEDROOM_TEXTURE
	_letter.visible = false
	_fade.visible = true
	_fade.color.a = 1.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_fade, "color:a", 0.0, 0.45)
	tween.finished.connect(func(): _fade.visible = false, CONNECT_ONE_SHOT)
	_play_letter_prop()


func _show_downstairs_scene() -> void:
	_hide_letter()
	_background.texture = HOME_TEXTURE
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_background.modulate.a = 0.0
	tween.set_parallel(true)
	tween.tween_property(_background, "modulate:a", 1.0, 0.5)


func _play_scratch_effect() -> void:
	_flash_caption("沙……沙……")
	for index in range(3):
		var scratch := ColorRect.new()
		scratch.color = Color(0.82, 0.75, 0.64, 0.8)
		scratch.position = Vector2(180 + index * 22, 306)
		scratch.size = Vector2(4, 42)
		scratch.rotation = -0.22
		_effect_layer.add_child(scratch)
		var tween := create_tween()
		tween.tween_property(scratch, "position:y", 326.0, 0.18).set_delay(index * 0.07)
		tween.tween_property(scratch, "modulate:a", 0.0, 0.35)
		tween.tween_callback(scratch.queue_free)


func _shake_stage(strength: float) -> void:
	var origin := _stage.position
	var tween := create_tween()
	for offset in [Vector2(strength, 0), Vector2(-strength, 2), Vector2(strength * 0.5, -1), Vector2.ZERO]:
		tween.tween_property(_stage, "position", origin + offset, 0.055)


func _flash_caption(text: String) -> void:
	_caption.text = text
	_caption.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_caption, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.85)
	tween.tween_property(_caption, "modulate:a", 0.0, 0.35)


func _play_letter_prop() -> void:
	var scroll := Panel.new()
	scroll.position = Vector2(230, 410)
	scroll.size = Vector2(88, 26)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e5d3a5")
	style.border_color = Color("#36a9a8")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	scroll.add_theme_stylebox_override("panel", style)
	_effect_layer.add_child(scroll)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scroll.scale = Vector2.ZERO
	tween.tween_property(scroll, "scale", Vector2.ONE, 0.35)
	tween.tween_interval(3.0)
	tween.tween_property(scroll, "modulate:a", 0.0, 0.25)
	tween.tween_callback(scroll.queue_free)


func _show_letter_closeup() -> void:
	_letter.visible = true
	_letter.scale = Vector2(0.82, 0.82)
	_letter.pivot_offset = _letter.size * 0.5
	_letter.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_letter, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_letter, "modulate:a", 1.0, 0.3)


func _hide_letter() -> void:
	if _letter != null:
		_letter.visible = false


func _highlight_potion(color: Color, x_offset: float) -> void:
	var bottle := Panel.new()
	bottle.position = Vector2(565 + x_offset, 388)
	bottle.size = Vector2(40, 76)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.78)
	style.border_color = Color(0.93, 0.93, 0.88, 0.9)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	bottle.add_theme_stylebox_override("panel", style)
	_effect_layer.add_child(bottle)
	bottle.pivot_offset = bottle.size * 0.5
	bottle.scale = Vector2(0.4, 0.4)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bottle, "scale", Vector2.ONE, 0.28)
	tween.tween_property(bottle, "modulate", Color(1.35, 1.35, 1.35, 1.0), 0.2)
	tween.tween_property(bottle, "modulate:a", 0.0, 0.45).set_delay(0.55)
	tween.tween_callback(bottle.queue_free)


func _play_supply_magic() -> void:
	_call_sound_manager(&"play_spell_cast")
	var ring := Panel.new()
	ring.position = Vector2(467, 345)
	ring.size = Vector2(160, 160)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.3, 0.34, 0.15)
	style.border_color = Color("#40c7c7")
	style.set_border_width_all(5)
	style.corner_radius_top_left = 80
	style.corner_radius_top_right = 80
	style.corner_radius_bottom_left = 80
	style.corner_radius_bottom_right = 80
	ring.add_theme_stylebox_override("panel", style)
	var runes := Label.new()
	runes.text = "✦  ◇  ✧\n  ◌\n✧  ◇  ✦"
	runes.position = Vector2(20, 23)
	runes.size = Vector2(120, 120)
	runes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	runes.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	runes.add_theme_font_size_override("font_size", 24)
	runes.add_theme_color_override("font_color", Color("#8ff4ee"))
	ring.add_child(runes)
	_effect_layer.add_child(ring)
	ring.pivot_offset = ring.size * 0.5
	ring.scale = Vector2(0.2, 0.2)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ring, "scale", Vector2.ONE, 0.55)
	tween.tween_property(ring, "rotation", TAU, 2.2)
	tween.tween_property(ring, "modulate:a", 0.0, 0.6).set_delay(1.6)
	tween.chain().tween_callback(ring.queue_free)


func _show_tutorial(text: String) -> void:
	_tutorial_text.text = text
	_tutorial.visible = true
	_tutorial.modulate.a = 0.0
	_tutorial.scale = Vector2(0.9, 0.9)
	_tutorial.pivot_offset = _tutorial.size * 0.5
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_tutorial, "modulate:a", 1.0, 0.28)
	tween.tween_property(_tutorial, "scale", Vector2.ONE, 0.38)


func _hide_tutorial() -> void:
	if _tutorial != null:
		_tutorial.visible = false


func _play_color_mixing() -> void:
	_hide_tutorial()
	_call_sound_manager(&"play_spell_cast")
	_show_tutorial("[center][color=#42caca][font_size=30]色彩调配[/font_size][/color]\n\n绿色 + 蓝色　→　[color=#40c7c7]青色区间[/color]\n\n目标配方：[color=#40c7c7]涌水药水[/color][/center]")
	for data in [[Color("#68c56a"), Vector2(395, 410)], [Color("#579bd8"), Vector2(718, 410)]]:
		var orb := ColorRect.new()
		orb.color = data[0]
		orb.position = data[1]
		orb.size = Vector2(26, 26)
		_effect_layer.add_child(orb)
		var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(orb, "position", Vector2(563, 385), 0.8)
		tween.tween_property(orb, "modulate:a", 0.0, 0.2)
		tween.tween_callback(orb.queue_free)


func _play_cyan_success() -> void:
	_hide_tutorial()
	_call_sound_manager(&"play_spell_release")
	_highlight_potion(Color("#40c7c7"), 0.0)
	for index in range(10):
		var drop := ColorRect.new()
		drop.color = Color(0.35, 0.95, 0.95, 0.9)
		drop.position = Vector2(570, 420)
		drop.size = Vector2(5, 12)
		drop.rotation = index * TAU / 10.0
		_effect_layer.add_child(drop)
		var target := Vector2(570, 420) + Vector2.RIGHT.rotated(drop.rotation) * 110.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(drop, "position", target, 0.55)
		tween.tween_property(drop, "modulate:a", 0.0, 0.55)
		tween.chain().tween_callback(drop.queue_free)
	_flash_caption("配方稳定 · 水纹正在瓶中旋转")


func _play_pack_effect() -> void:
	_hide_tutorial()
	_flash_caption("剧情道具获得 · 涌水药水（委托品）×4")
	for index in range(4):
		var bottle := ColorRect.new()
		bottle.color = Color("#40c7c7")
		bottle.position = Vector2(500 + index * 42, 415)
		bottle.size = Vector2(20, 46)
		_effect_layer.add_child(bottle)
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(bottle, "position", Vector2(920, 460), 0.45).set_delay(index * 0.08)
		tween.tween_property(bottle, "modulate:a", 0.0, 0.2)
		tween.tween_callback(bottle.queue_free)


func _play_morning_light() -> void:
	_hide_tutorial()
	_call_sound_manager(&"play_door_transition")
	var light := ColorRect.new()
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light.color = Color(1.0, 0.91, 0.64, 0.0)
	_effect_layer.add_child(light)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(light, "color:a", 0.42, 0.7)
	_flash_caption("药典屋的大门打开，晨光照入室内")


func _play_white_transition() -> void:
	_hide_tutorial()
	_fade.visible = true
	_fade.color = Color(1.0, 1.0, 1.0, 0.0)
	_caption.text = ""
	_caption.modulate.a = 0.0
	var fade_out := create_tween().set_trans(Tween.TRANS_SINE)
	fade_out.tween_property(_fade, "color:a", 1.0, 0.55)
	await fade_out.finished
	await get_tree().create_timer(1.0).timeout


func _finish_and_depart() -> void:
	var data := _player_data()
	if data != null:
		data.set_event_flag(COMPLETE_FLAG)
		data.set_event_flag(SUPPLY_FLAG)
		data.set_event_flag(CYAN_RECIPE_FLAG)
		data.unlock_level(DESTINATION_ID)
		data.set_active_home_destination(DESTINATION_ID)
		data.set_active_daily_task(TASK_ID, "将涌水药水送往涟汀村。", REQUIRED_DAY)
		_grant_commission_story_items(data)
		data.tutorial_flags[DayRuntime.scene_title_seen_key(REQUIRED_DAY, DESTINATION_ID)] = true
	var runtime := _find_runtime()
	if runtime != null:
		if not _modal_lock_was_set:
			get_tree().remove_meta("day_modal_input_locked")
		runtime.switch_to_level(str(DESTINATION_ID), &"default")
	_completed = true
	_running = false
	opening_completed.emit()
	if runtime == null:
		_cleanup_player()


func _cleanup_player() -> void:
	if _player != null:
		_player.visible = true
		_player.set_physics_process(true)
	if get_tree() != null and not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")
	visible = false


func _grant_commission_story_items(data: PlayerData) -> void:
	SpringburstProgression.grant_story_bottles(data, 4)


func _exit_tree() -> void:
	if _running:
		_running = false
		_cleanup_player()


func _current_day() -> int:
	var runtime := _find_runtime()
	return runtime.day if runtime != null else -1


func _player_data() -> PlayerData:
	var runtime := _find_runtime()
	return runtime.get_player_data() if runtime != null else null


func _find_runtime() -> DayRuntime:
	var current: Node = get_parent()
	while current != null:
		if current is DayRuntime:
			return current as DayRuntime
		current = current.get_parent()
	return null


func _call_sound_manager(method_name: StringName) -> void:
	var sound_manager := get_node_or_null("/root/SoundManager") as Node
	if sound_manager != null and sound_manager.has_method(method_name):
		sound_manager.call(method_name)
