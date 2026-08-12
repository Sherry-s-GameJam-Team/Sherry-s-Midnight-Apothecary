extends Control

signal travel_requested(destination_id: StringName, destination_data: Dictionary)
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

@export var open_on_ready := false
@export var device_scale := 0.42

var destinations: Array = [
	{"id": &"lumenstreet_market", "name": "Lumenstreet Market", "subtitle": "Night Trade District", "pos": Vector2(-120, -72), "danger": "LOW", "distance": "1 relay", "environment": "Urban / Arcane", "description": "A stable civilian anchor linked to the apothecary's night market corridor."},
	{"id": &"raintree_forest", "name": "Rain Tree Forest", "subtitle": "Wet Alchemy Woods", "pos": Vector2(82, -142), "danger": "MEDIUM", "distance": "2 relays", "environment": "Forest / Rain", "description": "Dense medicinal flora. Arcane moisture causes periodic route drift."},
	{"id": &"white_stone_lake", "name": "White Stone Lake", "subtitle": "Receded Shoreline", "pos": Vector2(192, 34), "danger": "MEDIUM", "distance": "3 relays", "environment": "Lake / Ruins", "description": "The retreating waterline exposes old stone structures and unstable channels."},
	{"id": &"maplewood_pass", "name": "Maplewood Pass", "subtitle": "Autumn Border Route", "pos": Vector2(64, 188), "danger": "HIGH", "distance": "4 relays", "environment": "Forest / Ravine", "description": "A narrow red-gold forest route with strong cross-current interference."},
]

@onready var device_stage: Node2D = %DeviceStage
@onready var map_viewport: SubViewport = %MapViewport
@onready var map_canvas: MagicMapCanvas = %MagicMapCanvas
@onready var circular_display: Sprite2D = %CircularDisplay
@onready var display_material: ShaderMaterial = %CircularDisplay.material as ShaderMaterial
@onready var crosshair: MapCrosshair = %FixedSelectionCursor
@onready var magic_overlay: DialMagicOverlay = %MagicOverlay
@onready var lever: LeverConfirm = %TravelConfirmLever
@onready var title_label: Label = %DestinationTitle
@onready var subtitle_label: Label = %DestinationSubtitle
@onready var danger_label: Label = %DangerLabel
@onready var distance_label: Label = %DistanceLabel
@onready var environment_label: Label = %EnvironmentLabel
@onready var description_label: Label = %DescriptionLabel
@onready var status_label: Label = %StatusLabel
@onready var activate_button: Button = %ActivateButton
@onready var reset_button: Button = %ResetButton
@onready var lever_hint: Label = %LeverHint

var _is_active := false
var _is_transitioning := false
var _dragging_map := false
var _keyboard_panning := false
var _last_map_mouse := Vector2.ZERO
var _selected_index := -1
var _locked_player: CharacterBody2D
var _locked_player_physics := false
var _dormant_device_position := Vector2.ZERO

func _ready() -> void:
	device_stage.scale = Vector2.ONE * device_scale
	_dormant_device_position = device_stage.position
	# Assign the live texture from the actual viewport node. This is deliberately
	# explicit so an inherited test scene cannot lose the ViewportTexture path.
	circular_display.texture = map_viewport.get_texture()
	destinations = map_canvas.get_authored_destinations(destinations)
	map_canvas.set_destinations(destinations)
	map_canvas.candidate_changed.connect(_on_map_candidate_changed)
	lever.committed.connect(_on_lever_committed)
	lever.pull_changed.connect(_on_lever_pull_changed)
	activate_button.pressed.connect(activate)
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
	hide()
	_unlock_world_input()

func activate() -> void:
	if _is_transitioning or _is_active:
		return
	_is_transitioning = true
	activate_button.disabled = true
	status_label.text = "Arcane stabilizers charging..."
	magic_overlay.intensity = 1.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_transition_progress, 0.0, 1.0, 1.35)
	tween.parallel().tween_method(_set_magic_intensity, 1.0, 0.0, 1.55)
	tween.parallel().tween_property(device_stage, "scale", Vector2.ONE * ACTIVE_DEVICE_SCALE, 0.55)
	tween.parallel().tween_property(device_stage, "position", _active_device_position(), 0.55)
	tween.finished.connect(func() -> void:
		_is_transitioning = false
		_is_active = true
		crosshair.active = true
		status_label.text = "MAP ONLINE. Drag the chart and bring a route node to the center cursor."
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
	map_canvas.reset_map()
	display_material.set_shader_parameter("transition_progress", 0.0)
	magic_overlay.intensity = 0.0
	activate_button.disabled = false
	device_stage.scale = Vector2.ONE * device_scale
	device_stage.position = _dormant_device_position
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
	lever_hint.text = "LOCK A NODE FIRST"
	_set_ui_waiting_for_selection()

func _select_destination(index: int) -> void:
	if index < 0 or index >= destinations.size():
		return
	_selected_index = index
	map_canvas.snap_to(index)
	var data: Dictionary = destinations[index]
	title_label.text = str(data.get("name", "Unknown"))
	subtitle_label.text = str(data.get("subtitle", ""))
	danger_label.text = "RISK       " + str(data.get("danger", "UNKNOWN"))
	distance_label.text = "DISTANCE   " + str(data.get("distance", "--"))
	environment_label.text = "BIOME      " + str(data.get("environment", "--"))
	description_label.text = str(data.get("description", ""))
	status_label.text = "ANCHOR LOCKED. Pull the confirm lever downward to emit the travel request signal."
	lever_hint.text = "PULL DOWN TO CONFIRM"
	lever.set_enabled(true)
	destination_selected.emit(data.get("id", &"unknown"), data)

func _on_map_candidate_changed(index: int, strength: float) -> void:
	if not _is_active or _selected_index >= 0:
		return
	status_label.text = "Magnetic capture: %s  %d%%" % [str(destinations[index].get("name", "route node")), int(strength * 100.0)] if index >= 0 and strength > 0.05 else "MAP ONLINE. Drag the chart and bring a route node to the center cursor."

func _on_lever_pull_changed(ratio: float) -> void:
	if _selected_index >= 0 and ratio > 0.02:
		lever_hint.text = "CONFIRM %d%%" % int(ratio * 100.0)

func _on_lever_committed() -> void:
	if _selected_index < 0:
		return
	var data: Dictionary = destinations[_selected_index]
	status_label.text = "ROUTE CONFIRMED: %s" % str(data.get("name", "Unknown"))
	lever_hint.text = "SIGNAL SENT"
	lever.set_enabled(false)
	travel_requested.emit(data.get("id", &"unknown"), data)

func _set_transition_progress(value: float) -> void:
	display_material.set_shader_parameter("transition_progress", value)

func _set_magic_intensity(value: float) -> void:
	magic_overlay.intensity = value

func _set_ui_dormant() -> void:
	title_label.text = "ARCANE DIAL"
	subtitle_label.text = "Device Dormant"
	danger_label.text = "RISK       --"
	distance_label.text = "DISTANCE   --"
	environment_label.text = "BIOME      --"
	description_label.text = "The circular instrument begins in the supplied rune-wheel state. Activate the device to dissolve it into the live map."
	status_label.text = "Press ACTIVATE DEVICE."
	lever_hint.text = "LOCK A NODE FIRST"

func _set_ui_waiting_for_selection() -> void:
	title_label.text = "NO ANCHOR LOCKED"
	subtitle_label.text = "Map Online"
	danger_label.text = "RISK       --"
	distance_label.text = "DISTANCE   --"
	environment_label.text = "BIOME      --"
	description_label.text = "Drag the map beneath the fixed center cursor. Nodes become magnetized near the center."
	status_label.text = "Bring a route node to the center cursor."

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

func _active_device_position() -> Vector2:
	return ACTIVE_DISPLAY_SCREEN_CENTER - DEVICE_DISPLAY_CENTER * ACTIVE_DEVICE_SCALE
