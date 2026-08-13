class_name PauseMenu
extends Control

const SettingsServiceScript := preload("res://app/settings_service.gd")

signal resumed
signal page_changed(page: Page)

enum Page {
	SETTINGS,
	CODEX,
	BACKPACK,
	HELP,
}

const DESIGN_SIZE := Vector2(1554.0, 1086.0)

@onready var design_root: Control = $DesignRoot
@onready var dimmer: ColorRect = $Dimmer
@onready var page_title: Label = $DesignRoot/PageTitle
@onready var page_body: RichTextLabel = $DesignRoot/PageBody
@onready var settings_panel: ScrollContainer = $DesignRoot/SettingsScroll
@onready var master_volume: HSlider = %MasterVolume
@onready var music_volume: HSlider = %MusicVolume
@onready var sfx_volume: HSlider = %SFXVolume
@onready var ui_volume: HSlider = %UIVolume
@onready var window_mode: OptionButton = %WindowMode
@onready var resolution: OptionButton = %Resolution
@onready var vsync_toggle: CheckButton = %VSyncToggle
@onready var text_size: OptionButton = %TextSize
@onready var dialogue_speed: OptionButton = %DialogueSpeed
@onready var reduced_motion: CheckButton = %ReducedMotion
@onready var reset_button: Button = %ResetButton
@onready var inventory_page: PauseInventoryPage = %InventoryPage

@onready var bookmark_settings: TextureButton = $DesignRoot/BookmarkSettings
@onready var bookmark_codex: TextureButton = $DesignRoot/BookmarkCodex
@onready var bookmark_return: TextureButton = $DesignRoot/BookmarkReturn
@onready var bookmark_backpack: TextureButton = $DesignRoot/BookmarkBackpack
@onready var bookmark_help: TextureButton = $DesignRoot/BookmarkHelp

var active_page := Page.SETTINGS
var _paused_before_open := false
var _open_target_position := Vector2.ZERO
var _open_tween: Tween
var _is_opening := false
var settings_service: Node
var _reset_armed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bookmark_settings.pressed.connect(select_page.bind(Page.SETTINGS))
	bookmark_codex.pressed.connect(select_page.bind(Page.CODEX))
	bookmark_return.pressed.connect(close)
	bookmark_backpack.pressed.connect(select_page.bind(Page.BACKPACK))
	bookmark_help.pressed.connect(select_page.bind(Page.HELP))
	_setup_option_buttons()
	master_volume.value_changed.connect(_set_setting.bind(&"master_volume"))
	music_volume.value_changed.connect(_set_setting.bind(&"music_volume"))
	sfx_volume.value_changed.connect(_set_setting.bind(&"sfx_volume"))
	ui_volume.value_changed.connect(_set_setting.bind(&"ui_volume"))
	window_mode.item_selected.connect(_on_window_mode_selected)
	resolution.item_selected.connect(_on_resolution_selected)
	vsync_toggle.toggled.connect(_set_setting.bind(&"vsync"))
	text_size.item_selected.connect(_set_setting.bind(&"text_size"))
	dialogue_speed.item_selected.connect(_set_setting.bind(&"dialogue_speed"))
	reduced_motion.toggled.connect(_set_setting.bind(&"reduced_motion"))
	reset_button.pressed.connect(_on_reset_pressed)
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


func bind_player_data(shared_player_data: PlayerData) -> void:
	if is_node_ready():
		inventory_page.bind_player_data(shared_player_data)
	else:
		await ready
		inventory_page.bind_player_data(shared_player_data)


func bind_settings(service: Node) -> void:
	settings_service = service
	if not is_node_ready():
		await ready
	if not settings_service.settings_changed.is_connected(_on_settings_changed):
		settings_service.settings_changed.connect(_on_settings_changed)
	_sync_settings_controls()


func select_page(page: Page) -> void:
	active_page = page
	settings_panel.visible = page == Page.SETTINGS
	inventory_page.visible = page == Page.BACKPACK
	page_body.visible = page == Page.CODEX or page == Page.HELP
	match page:
		Page.SETTINGS:
			page_title.text = "设置"
		Page.CODEX:
			page_title.text = "图鉴"
			page_body.text = "[center][font_size=30]材料 · 药水 · 配方[/font_size]\n\n发现的炼药资料将在这里陈列。[/center]"
		Page.BACKPACK:
			page_title.text = "背包"
			inventory_page.refresh()
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
	if not visible:
		return
	if event.is_action_pressed("open_backpack"):
		if active_page == Page.BACKPACK:
			close()
		else:
			select_page(Page.BACKPACK)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
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
	if settings_service != null and bool(settings_service.get_value(&"reduced_motion", false)):
		design_root.position = _open_target_position
		_open_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_open_tween.tween_property(dimmer, "modulate:a", 1.0, 0.1)
		_open_tween.finished.connect(_on_open_animation_finished)
		return

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
		Page.BACKPACK:
			return bookmark_backpack
		_:
			return bookmark_help


func _update_bookmark_highlight() -> void:
	for button: TextureButton in [
		bookmark_settings,
		bookmark_codex,
		bookmark_backpack,
		bookmark_help,
	]:
		button.self_modulate = Color.WHITE
	_active_bookmark().self_modulate = Color(1.12, 1.08, 0.88, 1.0)


func _sync_settings_controls() -> void:
	if settings_service == null:
		return
	master_volume.set_value_no_signal(float(settings_service.get_value(&"master_volume", 1.0)))
	music_volume.set_value_no_signal(float(settings_service.get_value(&"music_volume", 1.0)))
	sfx_volume.set_value_no_signal(float(settings_service.get_value(&"sfx_volume", 1.0)))
	ui_volume.set_value_no_signal(float(settings_service.get_value(&"ui_volume", 1.0)))
	window_mode.select(int(settings_service.get_value(&"window_mode", 0)))
	var saved_resolution: Array = settings_service.get_value(&"resolution", [1280, 720])
	var resolution_index: int = SettingsServiceScript.RESOLUTIONS.find(Vector2i(int(saved_resolution[0]), int(saved_resolution[1])))
	resolution.select(maxi(resolution_index, 0))
	resolution.disabled = window_mode.selected != 0
	vsync_toggle.set_pressed_no_signal(bool(settings_service.get_value(&"vsync", true)))
	text_size.select(int(settings_service.get_value(&"text_size", 1)))
	dialogue_speed.select(int(settings_service.get_value(&"dialogue_speed", 1)))
	reduced_motion.set_pressed_no_signal(bool(settings_service.get_value(&"reduced_motion", false)))


func _setup_option_buttons() -> void:
	for label in ["窗口", "无边框窗口", "独占全屏"]:
		window_mode.add_item(label)
	for size in SettingsServiceScript.RESOLUTIONS:
		resolution.add_item("%d × %d" % [size.x, size.y])
	for label in ["小", "标准", "大", "特大"]:
		text_size.add_item(label)
	for label in ["慢", "标准", "快", "即时"]:
		dialogue_speed.add_item(label)


func _set_setting(value: Variant, key: StringName) -> void:
	if settings_service != null:
		settings_service.set_value(key, value)


func _on_window_mode_selected(index: int) -> void:
	_set_setting(index, &"window_mode")
	resolution.disabled = index != 0


func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < SettingsServiceScript.RESOLUTIONS.size():
		var size: Vector2i = SettingsServiceScript.RESOLUTIONS[index]
		_set_setting([size.x, size.y], &"resolution")


func _on_settings_changed(_section: StringName) -> void:
	_sync_settings_controls()


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		reset_button.text = "再次点击确认恢复默认（3秒）"
		await get_tree().create_timer(3.0, true, false, true).timeout
		_reset_armed = false
		reset_button.text = "恢复默认设置"
		return
	_reset_armed = false
	reset_button.text = "恢复默认设置"
	if settings_service != null:
		settings_service.reset_defaults()
