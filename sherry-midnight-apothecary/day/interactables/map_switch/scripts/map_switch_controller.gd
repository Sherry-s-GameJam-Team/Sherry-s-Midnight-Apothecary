extends Control

signal destination_locked(destination_id: StringName, destination_data: Dictionary)
signal destination_selected(destination_id: StringName, destination_data: Dictionary)
signal activation_finished

const DEVICE_DISPLAY_CENTER := Vector2(543.0, 337.0)
const DEVICE_DISPLAY_DIAMETER := 424.0
const MAP_VIEWPORT_SIZE := Vector2i(512, 512)
const SNAP_RADIUS := 108.0
const MAGNET_RADIUS := 94.0
const KEYBOARD_PAN_SPEED := 360.0
const ACTIVE_DEVICE_SCALE := 1.0
const ACTIVE_DISPLAY_SCREEN_CENTER := Vector2(320.0, 360.0)
const ACTIVATION_BUTTON_FADE_DURATION := 0.28
const ALIGNMENT_TUTORIAL_FLAG := "home_transformer_map_alignment_completed"
const ALIGNMENT_TUTORIAL_HINT_ID := "home_transformer_map_alignment"
const ALIGNMENT_TUTORIAL_TEXT := "拖动鼠标，或使用 [W][A][S][D] 移动地图，将传送锚点对齐中央光标。"

@export var open_on_ready := false
@export var device_scale := 0.42

var destinations: Array = [
	{"id": &"lumenstreet_market", "name": "Lumenstreet Market", "subtitle": "Night Trade District", "pos": Vector2(-120, -72), "danger": "LOW", "distance": "1 relay", "environment": "Urban / Arcane", "description": "A stable civilian anchor linked to the apothecary's night market corridor."},
	{"id": &"raintree_forest", "name": "Rain Tree Forest", "subtitle": "Wet Alchemy Woods", "pos": Vector2(82, -142), "danger": "MEDIUM", "distance": "2 relays", "environment": "Forest / Rain", "description": "Dense medicinal flora. Arcane moisture causes periodic route drift."},
	{"id": &"white_stone_lake", "name": "White Stone Lake", "subtitle": "Receded Shoreline", "pos": Vector2(192, 34), "danger": "MEDIUM", "distance": "3 relays", "environment": "Lake / Ruins", "description": "The retreating waterline exposes old stone structures and unstable channels."},
	{"id": &"maplewood_pass", "name": "Maplewood Pass", "subtitle": "Autumn Border Route", "pos": Vector2(64, 188), "danger": "HIGH", "distance": "4 relays", "environment": "Forest / Ravine", "description": "A narrow red-gold forest route with strong cross-current interference."},
]

@onready var device_stage: Node2D = %DeviceStage
@onready var background: Sprite2D = $Bg
@onready var map_viewport: SubViewport = %MapViewport
@onready var map_canvas: MagicMapCanvas = %MagicMapCanvas
@onready var circular_display: Sprite2D = %CircularDisplay
@onready var display_material: ShaderMaterial = %CircularDisplay.material as ShaderMaterial
@onready var crosshair: MapCrosshair = %FixedSelectionCursor
@onready var magic_overlay: DialMagicOverlay = %MagicOverlay
@onready var lever: LeverConfirm = %TravelConfirmLever
@onready var title_label: Label = $DestinationPanel/DestinationColumn/DestinationTitle
@onready var subtitle_label: Label = $DestinationPanel/DestinationColumn/DestinationSubtitle
@onready var danger_label: Label = $DestinationPanel/DestinationColumn/DangerLabel
@onready var distance_label: Label = $DestinationPanel/DestinationColumn/DistanceLabel
@onready var environment_label: Label = $DestinationPanel/DestinationColumn/EnvironmentLabel
@onready var description_label: Label = $DestinationPanel/DestinationColumn/DescriptionLabel
@onready var status_label: Label = get_node_or_null("DestinationPanel/DestinationColumn/StatusLabel") as Label
@onready var activate_button: Button = $ActivateButton
@onready var confirm_button: Button = $ConfirmButton
@onready var reset_button: Button = $ResetButton
@onready var lever_hint: Label = %LeverHint
@onready var alignment_tutorial_hint: Label = %AlignmentTutorialHint
@onready var destination_column: VBoxContainer = $DestinationPanel/DestinationColumn

var _is_active := false
var _is_transitioning := false
var _dragging_map := false
var _keyboard_panning := false
var _last_map_mouse := Vector2.ZERO
var _selected_index := -1
var _locked_player: CharacterBody2D
var _locked_player_physics := false
var _dormant_device_position := Vector2.ZERO
var _dormant_background_scale := Vector2.ONE
var _alignment_tutorial_active := false
var _default_destination_title_font: Font
var _default_destination_title_font_size := 0
var _default_destination_title_horizontal_alignment := HORIZONTAL_ALIGNMENT_LEFT
var _default_destination_title_vertical_alignment := VERTICAL_ALIGNMENT_TOP
var _default_destination_title_vertical_size_flags := Control.SIZE_FILL
var _unlocked_instruction_font: SystemFont

func _ready() -> void:
	device_stage.scale = Vector2.ONE * device_scale
	_dormant_device_position = device_stage.position
	_dormant_background_scale = background.scale
	_default_destination_title_font = title_label.get_theme_font(&"font")
	_default_destination_title_font_size = title_label.get_theme_font_size(&"font_size")
	_default_destination_title_horizontal_alignment = title_label.horizontal_alignment
	_default_destination_title_vertical_alignment = title_label.vertical_alignment
	_default_destination_title_vertical_size_flags = title_label.size_flags_vertical
	_unlocked_instruction_font = SystemFont.new()
	_unlocked_instruction_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Source Han Sans SC", "sans-serif"])
	# Assign the live texture from the actual viewport node. This is deliberately
	# explicit so an inherited test scene cannot lose the ViewportTexture path.
	circular_display.texture = map_viewport.get_texture()
	destinations = map_canvas.get_authored_destinations(destinations)
	map_canvas.set_destinations(destinations)
	map_canvas.candidate_changed.connect(_on_map_candidate_changed)
	lever.committed.connect(_on_lever_committed)
	lever.pull_changed.connect(_on_lever_pull_changed)
	if activate_button != null:
		activate_button.pressed.connect(activate)
	confirm_button.pressed.connect(_confirm_selected_destination)
	reset_button.pressed.connect(close)
	_set_ui_dormant()
	if open_on_ready:
		show()
		reset_to_dial()

func open() -> void:
	if visible:
		return
	_lock_world_input()
	show()
	reset_to_dial()

func close() -> void:
	if not visible:
		return
	_dragging_map = false
	_hide_alignment_tutorial_hint()
	hide()
	_unlock_world_input()

func activate() -> void:
	if _is_transitioning or _is_active:
		return
	_is_transitioning = true
	_set_destination_details_visible(true)
	activate_button.disabled = true
	_set_status_text("Arcane stabilizers charging...")
	magic_overlay.intensity = 1.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_transition_progress, 0.0, 1.0, 1.35)
	tween.parallel().tween_method(_set_magic_intensity, 1.0, 0.0, 1.55)
	tween.parallel().tween_property(device_stage, "scale", Vector2.ONE * ACTIVE_DEVICE_SCALE, 0.55)
	tween.parallel().tween_property(device_stage, "position", _active_device_position(), 0.55)
	tween.parallel().tween_property(background, "scale", _dormant_background_scale * (ACTIVE_DEVICE_SCALE / maxf(device_scale, 0.001)), 0.55)
	tween.parallel().tween_property(activate_button, "modulate:a", 0.0, ACTIVATION_BUTTON_FADE_DURATION)
	tween.finished.connect(func() -> void:
		activate_button.hide()
		_is_transitioning = false
		_is_active = true
		crosshair.active = true
		_set_status_text("MAP ONLINE. Drag the chart and bring a route node to the center cursor.")
		_show_alignment_tutorial_if_needed()
		activation_finished.emit()
	)

func reset_to_dial() -> void:
	if _is_transitioning:
		return
	_is_active = false
	_dragging_map = false
	_selected_index = -1
	crosshair.active = false
	lever.set_enabled(false)
	confirm_button.hide()
	confirm_button.disabled = true
	map_canvas.reset_map()
	display_material.set_shader_parameter("transition_progress", 0.0)
	magic_overlay.intensity = 0.0
	activate_button.show()
	activate_button.modulate.a = 1.0
	activate_button.disabled = false
	device_stage.scale = Vector2.ONE * device_scale
	device_stage.position = _dormant_device_position
	background.scale = _dormant_background_scale
	_set_ui_dormant()

func configure_destinations(new_destinations: Array) -> void:
	destinations.clear()
	for destination in new_destinations:
		destinations.append(destination.to_dictionary() if destination is MapDestinationData else destination)
	_selected_index = -1
	lever.set_enabled(false)
	map_canvas.set_destinations(destinations)
	map_canvas.reset_map()
	if not _is_active:
		_set_ui_dormant()
	else:
		_set_ui_waiting_for_selection()

func _gui_input(event: InputEvent) -> void:
	if not _is_active or _is_transitioning:
		return
	var mouse_device := device_stage.to_local(get_viewport().get_mouse_position())
	var inside_display := mouse_device.distance_to(DEVICE_DISPLAY_CENTER) <= DEVICE_DISPLAY_DIAMETER * 0.5
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and inside_display:
			_clear_selection_for_drag()
			_dragging_map = true
			_last_map_mouse = mouse_device
			map_canvas.begin_drag()
			accept_event()
		elif not event.pressed and _dragging_map:
			_dragging_map = false
			var snap_index: int = map_canvas.end_drag(SNAP_RADIUS)
			if snap_index >= 0:
				_select_destination(snap_index)
			accept_event()
	elif event is InputEventMouseMotion and _dragging_map:
		var delta_viewport := (mouse_device - _last_map_mouse) / (DEVICE_DISPLAY_DIAMETER / float(MAP_VIEWPORT_SIZE.x))
		_last_map_mouse = mouse_device
		map_canvas.drag_by(delta_viewport, MAGNET_RADIUS)
		accept_event()
	elif event is InputEventMouseButton and inside_display:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			map_canvas.zoom_by(1.15)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			map_canvas.zoom_by(1.0 / 1.15)
			accept_event()

func _process(delta: float) -> void:
	if not visible or not _is_active or _is_transitioning or _dragging_map:
		return
	var direction := Vector2(
		float(Input.is_key_pressed(KEY_A)) - float(Input.is_key_pressed(KEY_D)),
		float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	)
	if not direction.is_zero_approx():
		if not _keyboard_panning:
			_clear_selection_for_drag()
			_keyboard_panning = true
			map_canvas.begin_drag()
		map_canvas.drag_by(direction.normalized() * KEYBOARD_PAN_SPEED * delta, MAGNET_RADIUS)
	elif _keyboard_panning:
		_keyboard_panning = false
		var snap_index: int = map_canvas.end_drag(SNAP_RADIUS)
		if snap_index >= 0:
			_select_destination(snap_index)

func _clear_selection_for_drag() -> void:
	if _selected_index < 0:
		return
	_selected_index = -1
	map_canvas.selected_index = -1
	lever.set_enabled(false)
	confirm_button.hide()
	confirm_button.disabled = true
	lever_hint.text = "LOCK A NODE FIRST"
	_set_ui_waiting_for_selection()

func _select_destination(index: int) -> void:
	if index < 0 or index >= destinations.size():
		return
	var data: Dictionary = destinations[index]
	var is_unlocked := can_lock_destination(data, _find_player_data())
	_complete_alignment_tutorial()
	_set_destination_details_visible(true)
	_set_destination_title_instruction_font(false)
	_selected_index = index
	map_canvas.snap_to(index)
	title_label.text = str(data.get("name", "Unknown"))
	subtitle_label.text = str(data.get("subtitle", ""))
	danger_label.text = "RISK       " + str(data.get("danger", "UNKNOWN"))
	distance_label.text = "盛产作物   " + str(data.get("distance", "--"))
	environment_label.text = "BIOME      " + str(data.get("environment", "--"))
	description_label.text = str(data.get("description", ""))
	if is_unlocked:
		_set_status_text("ANCHOR LOCKED. Confirm to lock this destination.")
		lever_hint.text = "PULL DOWN TO CONFIRM"
		lever.set_enabled(true)
		confirm_button.text = "确认锁定"
		confirm_button.disabled = false
	else:
		_set_status_text("ANCHOR INACTIVE. Complete the previous destination to activate it.")
		lever_hint.text = "ANCHOR INACTIVE"
		lever.set_enabled(false)
		confirm_button.text = "锚点未激活"
		confirm_button.disabled = true
	confirm_button.show()
	destination_selected.emit(data.get("id", &"unknown"), data)

func _on_map_candidate_changed(index: int, strength: float) -> void:
	if not _is_active or _selected_index >= 0:
		return
	_set_status_text("Magnetic capture: %s  %d%%" % [str(destinations[index].get("name", "route node")), int(strength * 100.0)] if index >= 0 and strength > 0.05 else "MAP ONLINE. Drag the chart and bring a route node to the center cursor.")

func _on_lever_pull_changed(ratio: float) -> void:
	if _selected_index >= 0 and ratio > 0.02:
		lever_hint.text = "CONFIRM %d%%" % int(ratio * 100.0)

func _on_lever_committed() -> void:
	_confirm_selected_destination()


func _confirm_selected_destination() -> void:
	if _selected_index < 0:
		return
	var data: Dictionary = destinations[_selected_index]
	if not can_lock_destination(data, _find_player_data()):
		confirm_button.disabled = true
		return
	_set_status_text("ROUTE CONFIRMED: %s" % str(data.get("name", "Unknown")))
	lever_hint.text = "SIGNAL SENT"
	lever.set_enabled(false)
	confirm_button.disabled = true
	destination_locked.emit(data.get("id", &"unknown"), data)

func _set_transition_progress(value: float) -> void:
	display_material.set_shader_parameter("transition_progress", value)

func _set_magic_intensity(value: float) -> void:
	magic_overlay.intensity = value

func _set_ui_dormant() -> void:
	_set_destination_details_visible(false)
	_set_destination_title_instruction_font(false)
	title_label.text = "设备未激活"
	lever_hint.text = "LOCK A NODE FIRST"

func _set_ui_waiting_for_selection() -> void:
	_set_destination_details_visible(false)
	_set_destination_title_instruction_font(true)
	title_label.text = "未锚定节点\n请使用鼠标或键盘 WASD 拖动地图至传送点位"


func _set_destination_details_visible(is_visible: bool) -> void:
	if destination_column == null:
		push_warning("MapSwitchInteraction is missing DestinationPanel/DestinationColumn.")
		return
	for child in destination_column.get_children():
		if child != title_label and child != activate_button:
			child.visible = is_visible
	title_label.visible = true


func _set_destination_title_instruction_font(is_instruction: bool) -> void:
	if is_instruction:
		title_label.add_theme_font_override(&"font", _unlocked_instruction_font)
		title_label.add_theme_font_size_override(&"font_size", max(1, roundi(_default_destination_title_font_size * 0.5)))
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		if _default_destination_title_font != null:
			title_label.add_theme_font_override(&"font", _default_destination_title_font)
		title_label.add_theme_font_size_override(&"font_size", _default_destination_title_font_size)
		title_label.horizontal_alignment = _default_destination_title_horizontal_alignment
		title_label.vertical_alignment = _default_destination_title_vertical_alignment
		title_label.size_flags_vertical = _default_destination_title_vertical_size_flags


func _set_status_text(value: String) -> void:
	if status_label != null:
		status_label.text = value

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _lock_world_input() -> void:
	get_tree().set_meta("day_modal_input_locked", true)
	_locked_player = _find_player()
	if _locked_player == null:
		return
	_locked_player_physics = _locked_player.is_physics_processing()
	_locked_player.set_physics_process(false)
	if _locked_player.has_method("set_potion_action_locked"):
		_locked_player.call("set_potion_action_locked", true)
	var thrower := _locked_player.get_node_or_null("PotionThrower")
	if thrower != null and thrower.has_method("cancel_aim"):
		thrower.call("cancel_aim")

func _unlock_world_input() -> void:
	get_tree().remove_meta("day_modal_input_locked")
	if _locked_player != null:
		_locked_player.set_physics_process(_locked_player_physics)
		if _locked_player.has_method("set_potion_action_locked"):
			_locked_player.call("set_potion_action_locked", false)
	_locked_player = null

func _find_player() -> CharacterBody2D:
	for node in get_tree().get_nodes_in_group("potion_friendly"):
		if node is CharacterBody2D and node.name == "Player":
			return node
	return null


func should_show_alignment_tutorial(player_data: PlayerData) -> bool:
	return player_data != null and not bool(player_data.tutorial_flags.get(ALIGNMENT_TUTORIAL_FLAG, false))


func can_lock_destination(destination_data: Dictionary, player_data: PlayerData) -> bool:
	# Standalone map previews do not have shared PlayerData and keep all anchors usable.
	if player_data == null:
		return true
	return player_data.has_unlocked_level(StringName(str(destination_data.get("id", ""))))


func _show_alignment_tutorial_if_needed() -> void:
	var player_data := _find_player_data()
	if not should_show_alignment_tutorial(player_data):
		return
	_alignment_tutorial_active = true
	alignment_tutorial_hint.text = ALIGNMENT_TUTORIAL_TEXT
	alignment_tutorial_hint.show()
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(ALIGNMENT_TUTORIAL_HINT_ID, ALIGNMENT_TUTORIAL_TEXT)


func _complete_alignment_tutorial() -> void:
	var player_data := _find_player_data()
	if not should_show_alignment_tutorial(player_data):
		return
	player_data.tutorial_flags[ALIGNMENT_TUTORIAL_FLAG] = true
	_alignment_tutorial_active = false
	alignment_tutorial_hint.hide()
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(ALIGNMENT_TUTORIAL_HINT_ID)


func _hide_alignment_tutorial_hint() -> void:
	if not _alignment_tutorial_active:
		return
	_alignment_tutorial_active = false
	alignment_tutorial_hint.hide()
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(ALIGNMENT_TUTORIAL_HINT_ID)


func _find_player_data() -> PlayerData:
	var current: Node = self
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return null


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI

func _active_device_position() -> Vector2:
	return ACTIVE_DISPLAY_SCREEN_CENTER - DEVICE_DISPLAY_CENTER * ACTIVE_DEVICE_SCALE
