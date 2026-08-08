extends Control

## Public integration signal.
## This demo NEVER changes scene. Connect this signal to your GameFlow/SceneRouter later.
signal travel_requested(destination_id: StringName, destination_data: Dictionary)
signal destination_selected(destination_id: StringName, destination_data: Dictionary)
signal activation_finished

const DEVICE_TEXTURE := preload("res://assets/device/transsformer.png")
const LEVER_TEXTURE := preload("res://assets/device/switch.png")
const DIAL_TEXTURE := preload("res://assets/device/wheel.png")
const DISPLAY_SHADER := preload("res://shaders/dial_to_map.gdshader")
const MAP_CANVAS_SCRIPT := preload("res://scripts/map_canvas.gd")
const CROSSHAIR_SCRIPT := preload("res://scripts/crosshair.gd")
const MAGIC_OVERLAY_SCRIPT := preload("res://scripts/magic_overlay.gd")
const LEVER_SCRIPT := preload("res://scripts/lever_confirm.gd")

# Coordinates are in the original 1086x1448 instrument texture.
const DEVICE_SOURCE_SIZE := Vector2(1086.0, 1448.0)
const DEVICE_DISPLAY_CENTER := Vector2(543.0, 337.0)
const DEVICE_DISPLAY_DIAMETER := 424.0
const MAP_VIEWPORT_SIZE := Vector2i(512, 512)
const SNAP_RADIUS := 108.0
const MAGNET_RADIUS := 94.0

var destinations: Array = [
    {
        "id": &"lumenstreet_market",
        "name": "Lumenstreet Market",
        "subtitle": "Night Trade District",
        "pos": Vector2(-120, -72),
        "danger": "LOW",
        "distance": "1 relay",
        "environment": "Urban / Arcane",
        "description": "A stable civilian anchor linked to the apothecary's night market corridor.",
    },
    {
        "id": &"raintree_forest",
        "name": "Rain Tree Forest",
        "subtitle": "Wet Alchemy Woods",
        "pos": Vector2(82, -142),
        "danger": "MEDIUM",
        "distance": "2 relays",
        "environment": "Forest / Rain",
        "description": "Dense medicinal flora. Arcane moisture causes periodic route drift.",
    },
    {
        "id": &"white_stone_lake",
        "name": "White Stone Lake",
        "subtitle": "Receded Shoreline",
        "pos": Vector2(192, 34),
        "danger": "MEDIUM",
        "distance": "3 relays",
        "environment": "Lake / Ruins",
        "description": "The retreating waterline exposes old stone structures and unstable channels.",
    },
    {
        "id": &"maplewood_pass",
        "name": "Maplewood Pass",
        "subtitle": "Autumn Border Route",
        "pos": Vector2(64, 188),
        "danger": "HIGH",
        "distance": "4 relays",
        "environment": "Forest / Ravine",
        "description": "A narrow red-gold forest route with strong cross-current interference.",
    },
    {
        "id": &"asterion_old_capital",
        "name": "Asterion Old Capital",
        "subtitle": "Royal Inner Ward",
        "pos": Vector2(-178, 158),
        "danger": "HIGH",
        "distance": "5 relays",
        "environment": "City / Royal",
        "description": "A high-load anchor. Authorization is valid, but the signal is heavily distorted.",
    },
    {
        "id": &"vialia_relay",
        "name": "Vialia Relay Station",
        "subtitle": "Itinerarium Anchor",
        "pos": Vector2(-282, -8),
        "danger": "LOW",
        "distance": "2 relays",
        "environment": "Transit / Neutral",
        "description": "A calibrated waypoint maintained by the Vialia Itinerarium network.",
    },
]

var _device_stage: Node2D
var _device_scale := 0.58
var _map_viewport: SubViewport
var _map_canvas
var _display_sprite: Sprite2D
var _display_material: ShaderMaterial
var _crosshair
var _magic_overlay
var _lever

var _title_label: Label
var _subtitle_label: Label
var _danger_label: Label
var _distance_label: Label
var _environment_label: Label
var _description_label: Label
var _status_label: Label
var _activate_button: Button
var _reset_button: Button
var _lever_hint: Label

var _is_active := false
var _is_transitioning := false
var _dragging_map := false
var _last_map_mouse := Vector2.ZERO
var _selected_index := -1

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    _build_demo_scene()
    _configure_map()
    _set_ui_dormant()

    # DEMO ONLY: prove that the component emits a signal without changing scene.
    # Remove this line after migration and connect travel_requested from your GameFlow.
    travel_requested.connect(_demo_receive_travel_signal)

func _build_demo_scene() -> void:
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("09070f")
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    var heading := Label.new()
    heading.text = "VIALIA ARCANE MAP SWITCH / GODOT 4.6"
    heading.position = Vector2(54, 24)
    heading.add_theme_font_size_override("font_size", 22)
    heading.add_theme_color_override("font_color", Color("d6b46e"))
    add_child(heading)

    var help := Label.new()
    help.text = "Activate -> drag the map -> snap a node to the fixed center cursor -> pull the lever."
    help.position = Vector2(54, 54)
    help.add_theme_font_size_override("font_size", 15)
    help.add_theme_color_override("font_color", Color(0.72, 0.72, 0.80, 1.0))
    add_child(help)

    _device_stage = Node2D.new()
    _device_stage.name = "DeviceStage"
    _device_stage.position = Vector2(54, 78)
    _device_stage.scale = Vector2.ONE * _device_scale
    add_child(_device_stage)

    var device := Sprite2D.new()
    device.texture = DEVICE_TEXTURE
    device.centered = false
    device.position = Vector2.ZERO
    _device_stage.add_child(device)

    _map_viewport = SubViewport.new()
    _map_viewport.name = "MapViewport"
    _map_viewport.size = MAP_VIEWPORT_SIZE
    _map_viewport.transparent_bg = false
    _map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(_map_viewport)

    _map_canvas = MAP_CANVAS_SCRIPT.new()
    _map_canvas.name = "MagicMapCanvas"
    _map_viewport.add_child(_map_canvas)

    _display_sprite = Sprite2D.new()
    _display_sprite.name = "CircularDisplay"
    _display_sprite.position = DEVICE_DISPLAY_CENTER
    _display_sprite.texture = _map_viewport.get_texture()
    var display_scale := DEVICE_DISPLAY_DIAMETER / float(MAP_VIEWPORT_SIZE.x)
    _display_sprite.scale = Vector2.ONE * display_scale
    _display_material = ShaderMaterial.new()
    _display_material.shader = DISPLAY_SHADER
    _display_material.set_shader_parameter("dial_texture", DIAL_TEXTURE)
    _display_material.set_shader_parameter("transition_progress", 0.0)
    _display_sprite.material = _display_material
    _device_stage.add_child(_display_sprite)

    _magic_overlay = MAGIC_OVERLAY_SCRIPT.new()
    _magic_overlay.name = "MagicOverlay"
    _magic_overlay.position = DEVICE_DISPLAY_CENTER
    _magic_overlay.radius = DEVICE_DISPLAY_DIAMETER * 0.5
    _device_stage.add_child(_magic_overlay)

    _crosshair = CROSSHAIR_SCRIPT.new()
    _crosshair.name = "FixedSelectionCursor"
    _crosshair.position = DEVICE_DISPLAY_CENTER
    _device_stage.add_child(_crosshair)

    _build_side_panel()
    _build_lever()
    _build_buttons()

func _build_side_panel() -> void:
    var panel := PanelContainer.new()
    panel.position = Vector2(1018, 126)
    panel.size = Vector2(510, 478)
    var box := StyleBoxFlat.new()
    box.bg_color = Color(0.055, 0.045, 0.085, 0.96)
    box.border_color = Color(0.58, 0.43, 0.22, 0.95)
    box.set_border_width_all(2)
    box.corner_radius_top_left = 12
    box.corner_radius_top_right = 12
    box.corner_radius_bottom_left = 12
    box.corner_radius_bottom_right = 12
    box.content_margin_left = 24
    box.content_margin_right = 24
    box.content_margin_top = 22
    box.content_margin_bottom = 22
    panel.add_theme_stylebox_override("panel", box)
    add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    panel.add_child(vbox)

    var small := Label.new()
    small.text = "DESTINATION READOUT"
    small.add_theme_font_size_override("font_size", 13)
    small.add_theme_color_override("font_color", Color("9d83c9"))
    vbox.add_child(small)

    _title_label = Label.new()
    _title_label.add_theme_font_size_override("font_size", 30)
    _title_label.add_theme_color_override("font_color", Color("e2c27d"))
    _title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    vbox.add_child(_title_label)

    _subtitle_label = Label.new()
    _subtitle_label.add_theme_font_size_override("font_size", 17)
    _subtitle_label.add_theme_color_override("font_color", Color(0.72, 0.75, 0.90, 1.0))
    vbox.add_child(_subtitle_label)

    var sep := HSeparator.new()
    vbox.add_child(sep)

    _danger_label = _make_info_label()
    _distance_label = _make_info_label()
    _environment_label = _make_info_label()
    vbox.add_child(_danger_label)
    vbox.add_child(_distance_label)
    vbox.add_child(_environment_label)

    _description_label = Label.new()
    _description_label.custom_minimum_size = Vector2(440, 112)
    _description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    _description_label.add_theme_font_size_override("font_size", 16)
    _description_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88, 1.0))
    vbox.add_child(_description_label)

    _status_label = Label.new()
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.add_theme_font_size_override("font_size", 14)
    _status_label.add_theme_color_override("font_color", Color("74d9ff"))
    vbox.add_child(_status_label)

func _make_info_label() -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", 15)
    label.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68, 1.0))
    return label

func _build_lever() -> void:
    var plate := Panel.new()
    plate.position = Vector2(825, 265)
    plate.size = Vector2(140, 420)
    var plate_style := StyleBoxFlat.new()
    plate_style.bg_color = Color(0.06, 0.05, 0.085, 0.86)
    plate_style.border_color = Color(0.38, 0.28, 0.16, 0.95)
    plate_style.set_border_width_all(2)
    plate_style.corner_radius_top_left = 10
    plate_style.corner_radius_top_right = 10
    plate_style.corner_radius_bottom_left = 10
    plate_style.corner_radius_bottom_right = 10
    plate.add_theme_stylebox_override("panel", plate_style)
    plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(plate)

    var lever_title := Label.new()
    lever_title.text = "CONFIRM"
    lever_title.position = Vector2(848, 284)
    lever_title.add_theme_font_size_override("font_size", 14)
    lever_title.add_theme_color_override("font_color", Color("c8a76c"))
    add_child(lever_title)

    _lever = LEVER_SCRIPT.new()
    _lever.name = "TravelConfirmLever"
    _lever.position = Vector2(895, 478)
    add_child(_lever)
    _lever.setup(LEVER_TEXTURE)
    _lever.committed.connect(_on_lever_committed)
    _lever.pull_changed.connect(_on_lever_pull_changed)

    _lever_hint = Label.new()
    _lever_hint.position = Vector2(840, 650)
    _lever_hint.size = Vector2(112, 54)
    _lever_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _lever_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _lever_hint.add_theme_font_size_override("font_size", 12)
    _lever_hint.add_theme_color_override("font_color", Color(0.60, 0.60, 0.68, 1.0))
    _lever_hint.text = "LOCK A NODE FIRST"
    add_child(_lever_hint)

func _build_buttons() -> void:
    _activate_button = Button.new()
    _activate_button.text = "ACTIVATE DEVICE"
    _activate_button.position = Vector2(1018, 628)
    _activate_button.size = Vector2(244, 48)
    _activate_button.pressed.connect(activate)
    add_child(_activate_button)

    _reset_button = Button.new()
    _reset_button.text = "RESET TO DIAL"
    _reset_button.position = Vector2(1284, 628)
    _reset_button.size = Vector2(244, 48)
    _reset_button.pressed.connect(reset_to_dial)
    add_child(_reset_button)

    var note := Label.new()
    note.text = "Demo behavior: lever emits travel_requested(...). No scene is changed."
    note.position = Vector2(1018, 695)
    note.size = Vector2(510, 54)
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 14)
    note.add_theme_color_override("font_color", Color(0.66, 0.66, 0.74, 1.0))
    add_child(note)

func _configure_map() -> void:
    _map_canvas.set_destinations(destinations)
    _map_canvas.candidate_changed.connect(_on_map_candidate_changed)

## Public API. Call this when the player interacts with the machine.
func activate() -> void:
    if _is_transitioning or _is_active:
        return
    _is_transitioning = true
    _activate_button.disabled = true
    _status_label.text = "Arcane stabilizers charging..."
    _magic_overlay.intensity = 1.0

    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_method(_set_transition_progress, 0.0, 1.0, 1.35)
    tween.parallel().tween_method(_set_magic_intensity, 1.0, 0.0, 1.55)
    tween.finished.connect(func():
        _is_transitioning = false
        _is_active = true
        _crosshair.active = true
        _status_label.text = "MAP ONLINE. Drag the chart and bring a route node to the center cursor."
        activation_finished.emit()
    )

## Public API. Useful for closing the machine UI or replaying the boot animation.
func reset_to_dial() -> void:
    if _is_transitioning:
        return
    _is_active = false
    _dragging_map = false
    _selected_index = -1
    _crosshair.active = false
    _lever.set_enabled(false)
    _map_canvas.reset_map()
    _display_material.set_shader_parameter("transition_progress", 0.0)
    _magic_overlay.intensity = 0.0
    _activate_button.disabled = false
    _set_ui_dormant()

## Public API. Replace demo data without editing this script.
func configure_destinations(new_destinations: Array) -> void:
    destinations = new_destinations.duplicate(true)
    _selected_index = -1
    _lever.set_enabled(false)
    _map_canvas.set_destinations(destinations)
    _map_canvas.reset_map()
    if not _is_active:
        _set_ui_dormant()
    else:
        _set_ui_waiting_for_selection()

func _set_transition_progress(value: float) -> void:
    _display_material.set_shader_parameter("transition_progress", value)

func _set_magic_intensity(value: float) -> void:
    _magic_overlay.intensity = value

func _gui_input(event: InputEvent) -> void:
    if not _is_active or _is_transitioning:
        return

    var mouse_screen := get_viewport().get_mouse_position()
    var mouse_device := _device_stage.to_local(mouse_screen)
    var inside_display := mouse_device.distance_to(DEVICE_DISPLAY_CENTER) <= DEVICE_DISPLAY_DIAMETER * 0.5

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and inside_display:
            if _selected_index >= 0:
                _selected_index = -1
                _map_canvas.selected_index = -1
                _lever.set_enabled(false)
                _lever_hint.text = "LOCK A NODE FIRST"
                _lever_hint.add_theme_color_override("font_color", Color(0.60, 0.60, 0.68, 1.0))
                _set_ui_waiting_for_selection()
            _dragging_map = true
            _last_map_mouse = mouse_device
            _map_canvas.begin_drag()
            accept_event()
        elif not event.pressed and _dragging_map:
            _dragging_map = false
            var snap_index := _map_canvas.end_drag(SNAP_RADIUS)
            if snap_index >= 0:
                _select_destination(snap_index)
            accept_event()
    elif event is InputEventMouseMotion and _dragging_map:
        var delta_device := mouse_device - _last_map_mouse
        _last_map_mouse = mouse_device
        var display_scale := DEVICE_DISPLAY_DIAMETER / float(MAP_VIEWPORT_SIZE.x)
        var delta_viewport := delta_device / display_scale
        _map_canvas.drag_by(delta_viewport, MAGNET_RADIUS)
        accept_event()

func _select_destination(index: int) -> void:
    if index < 0 or index >= destinations.size():
        return
    _selected_index = index
    _map_canvas.snap_to(index)
    var data: Dictionary = destinations[index]
    _title_label.text = str(data.get("name", "Unknown"))
    _subtitle_label.text = str(data.get("subtitle", ""))
    _danger_label.text = "RISK       " + str(data.get("danger", "UNKNOWN"))
    _distance_label.text = "DISTANCE   " + str(data.get("distance", "--"))
    _environment_label.text = "BIOME      " + str(data.get("environment", "--"))
    _description_label.text = str(data.get("description", ""))
    _status_label.text = "ANCHOR LOCKED. Pull the confirm lever downward to emit the travel request signal."
    _lever_hint.text = "PULL DOWN TO CONFIRM"
    _lever_hint.add_theme_color_override("font_color", Color("d8bc79"))
    _lever.set_enabled(true)
    destination_selected.emit(data.get("id", &"unknown"), data)

func _on_map_candidate_changed(index: int, strength: float) -> void:
    if not _is_active or _selected_index >= 0:
        return
    if index >= 0 and strength > 0.05:
        var name := str(destinations[index].get("name", "route node"))
        _status_label.text = "Magnetic capture: %s  %d%%" % [name, int(strength * 100.0)]
    else:
        _status_label.text = "MAP ONLINE. Drag the chart and bring a route node to the center cursor."

func _on_lever_pull_changed(ratio: float) -> void:
    if _selected_index < 0:
        return
    if ratio > 0.02:
        _lever_hint.text = "CONFIRM %d%%" % int(ratio * 100.0)

func _on_lever_committed() -> void:
    if _selected_index < 0 or _selected_index >= destinations.size():
        return
    var data: Dictionary = destinations[_selected_index]
    _status_label.text = "SIGNAL EMITTED: travel_requested(%s). Scene remains unchanged." % str(data.get("id", &"unknown"))
    _lever_hint.text = "SIGNAL SENT"
    travel_requested.emit(data.get("id", &"unknown"), data)

func _demo_receive_travel_signal(destination_id: StringName, _data: Dictionary) -> void:
    print("[MapSwitchDemo] travel_requested emitted for: ", destination_id, " (no scene switch in demo)")

func _set_ui_dormant() -> void:
    _title_label.text = "ARCANE DIAL"
    _subtitle_label.text = "Device Dormant"
    _danger_label.text = "RISK       --"
    _distance_label.text = "DISTANCE   --"
    _environment_label.text = "BIOME      --"
    _description_label.text = "The circular instrument begins in the supplied rune-wheel state. Activate the device to dissolve it into the live map."
    _status_label.text = "Press ACTIVATE DEVICE."
    _lever_hint.text = "LOCK A NODE FIRST"
    _lever_hint.add_theme_color_override("font_color", Color(0.60, 0.60, 0.68, 1.0))

func _set_ui_waiting_for_selection() -> void:
    _title_label.text = "NO ANCHOR LOCKED"
    _subtitle_label.text = "Map Online"
    _danger_label.text = "RISK       --"
    _distance_label.text = "DISTANCE   --"
    _environment_label.text = "BIOME      --"
    _description_label.text = "Drag the map beneath the fixed center cursor. Nodes become magnetized near the center."
    _status_label.text = "Bring a route node to the center cursor."
