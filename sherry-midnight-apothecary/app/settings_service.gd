class_name SettingsService
extends Node

signal settings_changed(section: StringName)

const DEFAULT_PATH := "user://settings.json"
const SAVE_DELAY := 0.15
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const TEXT_SCALES := [0.9, 1.0, 1.15, 1.3]
const DIALOGUE_SPEEDS := [0.055, 0.035, 0.018, 0.0]
const FONT_BASE_META := &"settings_font_base"

var settings_path := DEFAULT_PATH
var values: Dictionary = {}
var _save_timer: Timer


func _init(path := DEFAULT_PATH) -> void:
	settings_path = path
	values = defaults()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_save_timer.timeout.connect(_save_now)
	add_child(_save_timer)
	get_tree().node_added.connect(_on_node_added)


static func defaults() -> Dictionary:
	return {
		"version": 1,
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"ui_volume": 1.0,
		"window_mode": 0,
		"resolution": [1280, 720],
		"vsync": true,
		"text_size": 1,
		"dialogue_speed": 1,
		"reduced_motion": false,
	}


func load_and_apply() -> void:
	values = defaults()
	if FileAccess.file_exists(settings_path):
		var file := FileAccess.open(settings_path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		if parsed is Dictionary:
			_merge_valid(parsed as Dictionary)
	apply_all()


func reset_defaults() -> void:
	values = defaults()
	apply_all()
	_schedule_save()
	settings_changed.emit(&"all")


func get_value(key: StringName, fallback: Variant = null) -> Variant:
	return values.get(String(key), fallback)


func set_value(key: StringName, value: Variant) -> void:
	var candidate := values.duplicate(true)
	candidate[String(key)] = value
	var old := values
	values = defaults()
	_merge_valid(candidate)
	if values == old:
		return
	_apply_key(key)
	_schedule_save()
	settings_changed.emit(_section_for(key))


func flush() -> void:
	if _save_timer != null and not _save_timer.is_stopped():
		_save_timer.stop()
		_save_now()


func apply_all() -> void:
	_ensure_audio_buses()
	_apply_audio()
	_apply_display()
	_apply_text_scale(get_tree().root if is_inside_tree() else null)
	_apply_dialogue_speed(get_tree().root if is_inside_tree() else null)


func _exit_tree() -> void:
	flush()


func _merge_valid(source: Dictionary) -> void:
	for key in ["master_volume", "music_volume", "sfx_volume", "ui_volume"]:
		var number: Variant = source.get(key)
		if number is float or number is int:
			values[key] = clampf(float(number), 0.0, 1.0)
	var mode := int(source.get("window_mode", values.window_mode))
	if mode in [0, 1, 2]:
		values.window_mode = mode
	var resolution: Variant = source.get("resolution")
	if resolution is Array and resolution.size() == 2:
		var candidate := Vector2i(int(resolution[0]), int(resolution[1]))
		if candidate in RESOLUTIONS:
			values.resolution = [candidate.x, candidate.y]
	values.vsync = bool(source.get("vsync", values.vsync))
	values.text_size = clampi(int(source.get("text_size", values.text_size)), 0, TEXT_SCALES.size() - 1)
	values.dialogue_speed = clampi(int(source.get("dialogue_speed", values.dialogue_speed)), 0, DIALOGUE_SPEEDS.size() - 1)
	values.reduced_motion = bool(source.get("reduced_motion", values.reduced_motion))


func _apply_key(key: StringName) -> void:
	if key in [&"master_volume", &"music_volume", &"sfx_volume", &"ui_volume"]:
		_ensure_audio_buses()
		_apply_audio()
	elif key in [&"window_mode", &"resolution", &"vsync"]:
		_apply_display()
	elif key == &"text_size":
		_apply_text_scale(get_tree().root)
	elif key == &"dialogue_speed":
		_apply_dialogue_speed(get_tree().root)


func _ensure_audio_buses() -> void:
	_ensure_bus(&"Music", &"Master")
	_ensure_bus(&"SFX", &"Master")
	_ensure_bus(&"UI", &"Master")


func _ensure_bus(bus_name: StringName, send: StringName) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send)
	return index


func _apply_audio() -> void:
	_set_bus_level(&"Master", float(values.master_volume))
	_set_bus_level(&"Music", float(values.music_volume))
	_set_bus_level(&"SFX", float(values.sfx_volume))
	_set_bus_level(&"UI", float(values.ui_volume))


func _set_bus_level(bus_name: StringName, level: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, level <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.001)))


func _apply_display() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	match int(values.window_mode):
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		2:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size := Vector2i(int(values.resolution[0]), int(values.resolution[1]))
			DisplayServer.window_set_size(size)
			var screen := DisplayServer.window_get_current_screen()
			var usable := DisplayServer.screen_get_usable_rect(screen)
			DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


func _apply_text_scale(root: Node) -> void:
	if root == null:
		return
	_scale_control_tree(root, float(TEXT_SCALES[int(values.text_size)]), false)


func _scale_control_tree(node: Node, scale: float, excluded: bool) -> void:
	var now_excluded := excluded or node.is_in_group(&"developer_console") or "DeveloperConsole" in node.name or "Debug" in node.name
	if node is Control and not now_excluded:
		var control := node as Control
		for property: Dictionary in control.get_property_list():
			var property_name := StringName(property.name)
			if not String(property_name).begins_with("theme_override_font_sizes/"):
				continue
			var current_value: Variant = control.get(property_name)
			if not (current_value is int or current_value is float):
				continue
			var meta_key := StringName("%s_%s" % [FONT_BASE_META, String(property_name).replace("/", "_")])
			if not control.has_meta(meta_key):
				control.set_meta(meta_key, int(current_value))
			control.set(property_name, maxi(1, roundi(int(control.get_meta(meta_key)) * scale)))
	for child in node.get_children():
		_scale_control_tree(child, scale, now_excluded)


func _apply_dialogue_speed(root: Node) -> void:
	if root == null:
		return
	var seconds := float(DIALOGUE_SPEEDS[int(values.dialogue_speed)])
	for node in root.find_children("*", "DialogueLabel", true, false):
		node.set("seconds_per_step", seconds)
	for node in root.find_children("*", "TopHintUI", true, false):
		node.set("seconds_per_character", seconds)


func _on_node_added(node: Node) -> void:
	if node is Control:
		call_deferred("_apply_text_scale", node)
	if node is DialogueLabel or node is TopHintUI:
		call_deferred("_apply_dialogue_speed", node)


func _schedule_save() -> void:
	if _save_timer != null:
		_save_timer.start()


func _save_now() -> void:
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(values, "\t"))


static func _section_for(key: StringName) -> StringName:
	if key in [&"master_volume", &"music_volume", &"sfx_volume", &"ui_volume"]:
		return &"audio"
	if key in [&"window_mode", &"resolution", &"vsync"]:
		return &"display"
	return &"accessibility"
