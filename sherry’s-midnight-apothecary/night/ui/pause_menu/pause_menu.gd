class_name PauseMenu
extends Control

signal resumed
signal page_changed(page: Page)

enum Page {
	SETTINGS,
	CODEX,
	NOTES,
	HELP,
}

const DESIGN_SIZE := Vector2(1554.0, 1086.0)

@onready var design_root: Control = $DesignRoot
@onready var dimmer: ColorRect = $Dimmer
@onready var page_title: Label = $DesignRoot/PageTitle
@onready var page_body: RichTextLabel = $DesignRoot/PageBody
@onready var settings_panel: VBoxContainer = $DesignRoot/SettingsPanel
@onready var master_volume: HSlider = $DesignRoot/SettingsPanel/MasterVolume
@onready var fullscreen_toggle: CheckButton = $DesignRoot/SettingsPanel/FullscreenToggle

@onready var bookmark_settings: TextureButton = $DesignRoot/BookmarkSettings
@onready var bookmark_codex: TextureButton = $DesignRoot/BookmarkCodex
@onready var bookmark_return: TextureButton = $DesignRoot/BookmarkReturn
@onready var bookmark_notes: TextureButton = $DesignRoot/BookmarkNotes
@onready var bookmark_help: TextureButton = $DesignRoot/BookmarkHelp

var active_page := Page.SETTINGS
var _paused_before_open := false
var _open_target_position := Vector2.ZERO
var _open_tween: Tween
var _is_opening := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bookmark_settings.pressed.connect(select_page.bind(Page.SETTINGS))
	bookmark_codex.pressed.connect(select_page.bind(Page.CODEX))
	bookmark_return.pressed.connect(close)
	bookmark_notes.pressed.connect(select_page.bind(Page.NOTES))
	bookmark_help.pressed.connect(select_page.bind(Page.HELP))
	master_volume.value_changed.connect(_on_master_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	_sync_settings_controls()
	select_page(Page.SETTINGS)
	_fit_design()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_fit_design()
		if visible and _is_opening:
			_play_open_animation()


func open(initial_page := Page.SETTINGS) -> void:
	if visible:
		select_page(initial_page)
		return
	if is_inside_tree():
		_paused_before_open = get_tree().paused
		get_tree().paused = true
	visible = true
	select_page(initial_page)
	_fit_design()
	_play_open_animation()
	_active_bookmark().grab_focus()


func close() -> void:
	if not visible:
		return
	if _open_tween != null:
		_open_tween.kill()
	_open_tween = null
	_is_opening = false
	design_root.position = _open_target_position
	dimmer.modulate.a = 1.0
	visible = false
	if is_inside_tree():
		get_tree().paused = _paused_before_open
	resumed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open(active_page)


func select_page(page: Page) -> void:
	active_page = page
	settings_panel.visible = page == Page.SETTINGS
	page_body.visible = page != Page.SETTINGS
	match page:
		Page.SETTINGS:
			page_title.text = "设置"
		Page.CODEX:
			page_title.text = "图鉴"
			page_body.text = "[center][font_size=30]材料 · 药水 · 配方[/font_size]\n\n发现的炼药资料将在这里陈列。[/center]"
		Page.NOTES:
			page_title.text = "炼药记录"
			page_body.text = "[center][font_size=30]午夜手记[/font_size]\n\n今日的订单、配方与探索记录。[/center]"
		Page.HELP:
			page_title.text = "操作说明"
			page_body.text = "[center][font_size=30]右侧书签可切换页面[/font_size]\n\n按 Esc 或点击“返回”继续游戏。[/center]"
	_update_bookmark_highlight()
	page_changed.emit(active_page)


func is_opening() -> bool:
	return _is_opening


func get_open_target_position() -> Vector2:
	return _open_target_position


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _fit_design() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var fit_scale := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	design_root.scale = Vector2.ONE * fit_scale
	_open_target_position = (size - DESIGN_SIZE * fit_scale) * 0.5
	if not _is_opening:
		design_root.position = _open_target_position


func _play_open_animation() -> void:
	if _open_tween != null:
		_open_tween.kill()
	var rendered_height := DESIGN_SIZE.y * design_root.scale.y
	var start_offset := maxf(size.y, rendered_height) + 48.0
	design_root.position = _open_target_position + Vector2(0.0, start_offset)
	dimmer.modulate.a = 0.0
	_is_opening = true

	_open_tween = create_tween()
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tween.set_parallel(true)
	_open_tween.tween_property(
		design_root,
		"position",
		_open_target_position,
		0.42
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(dimmer, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_QUAD)
	_open_tween.finished.connect(_on_open_animation_finished)


func _on_open_animation_finished() -> void:
	_is_opening = false
	_open_tween = null
	design_root.position = _open_target_position
	dimmer.modulate.a = 1.0


func _active_bookmark() -> TextureButton:
	match active_page:
		Page.SETTINGS:
			return bookmark_settings
		Page.CODEX:
			return bookmark_codex
		Page.NOTES:
			return bookmark_notes
		_:
			return bookmark_help


func _update_bookmark_highlight() -> void:
	for button: TextureButton in [
		bookmark_settings,
		bookmark_codex,
		bookmark_notes,
		bookmark_help,
	]:
		button.self_modulate = Color.WHITE
	_active_bookmark().self_modulate = Color(1.12, 1.08, 0.88, 1.0)


func _sync_settings_controls() -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		master_volume.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(bus_index)))
	fullscreen_toggle.set_pressed_no_signal(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)


func _on_master_volume_changed(value: float) -> void:
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.001)))


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
