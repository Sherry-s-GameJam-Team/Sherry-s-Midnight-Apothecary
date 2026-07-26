extends Node2D

signal changer_transition_requested(from_node: String, to_node: String, from_index: int, to_index: int)
signal interior_exit_to_destination(destination_key: String)
signal interior_transition_progress_changed(destination_key: String, progress: float)

const HOME_TEXTURE = preload("res://art/town/backgrounds/home.png")
const HOME_INSIDE_TEXTURE = preload("res://art/town/backgrounds/home_inside.png")
const HOME_INSIDE_SHADOW_TEXTURE = preload("res://art/town/backgrounds/home_inside_shadow.png")
const MOSAIC_DISSOLVE_SHADER = preload("res://game/main/scenes/town/shaders/mosaic_dissolve.gdshader")
const MAP_SCENE = preload("res://game/main/scenes/doorchanger/map.tscn")
const INTERACTION_REMINDER_MANAGER_SCRIPT = preload("res://game/src/system/reminder/interaction_reminder_manager.gd")
const VISUAL_TRANSITION_DURATION = 0.7
const INTERIOR_CAMERA_OFFSET = Vector2(0.0, -30.0)
const DOOR_SWITCH_PADDING = 10.0
const DOOR_SWITCH_X_OFFSET = 36.0
const CLOCK_INTERACT_DISTANCE = 120.0
const CLOCK_INTERACTION_MESSAGE := "按下 E 打开地图"
const CLOCK_NEAR_MODULATE = Color(0.58, 0.58, 0.58, 1.0)
const CLOCK_DEFAULT_MODULATE = Color(1.0, 1.0, 1.0, 1.0)
const MAP_OVERLAY_LAYER = 130
const MAP_OVERLAY_FADE_DURATION = 0.18
const DEFAULT_PLAYER_HALF_WIDTH = 24.0
const INTERIOR_MIN_X = -430.0
const INTERIOR_MAX_X = 430.0
const NODE_DESTINATIONS := {
	"home": "",
	"point1": "raintree",
}

var is_inside_home := false
var is_transitioning := false
var is_camera_transitioning := false
var is_route_exit_requested := false
var is_camera_inside_view := false
var player: CharacterBody2D = null
var camera_controller: TownCameraController = null
var player_world_min_x := 0.0
var player_world_max_x := 0.0
var player_half_width := DEFAULT_PLAYER_HALF_WIDTH
var visual_tween: Tween = null
var map_overlay_tween: Tween = null
var home_transition_material: ShaderMaterial = null
var home_inside_shadow_transition_material: ShaderMaterial = null
var has_player_world_bounds := false
var map_overlay: CanvasLayer = null
var map_overlay_content: Node2D = null
var map_instance: Node = null
var interaction_reminder_manager: Node = null
var changer_node_name := "home"
var is_map_close_waiting_for_return := false
var is_map_destination_committing := false
var is_title_room_preview := false
var skip_next_outside_camera_transition := false
var has_title_room_camera_override := false
var title_room_camera_override := Vector2.ZERO

@onready var home: Sprite2D = get_node_or_null("Home") as Sprite2D
@onready var interior_room: Node2D = get_node_or_null("InteriorRoom") as Node2D
@onready var home_inside: Sprite2D = _get_interior_node("HomeInside") as Sprite2D
@onready var home_inside_shadow: Sprite2D = _get_interior_node("HomeInsideShadow") as Sprite2D
@onready var clock: Sprite2D = _get_interior_node("HomeInside/Clock") as Sprite2D
@onready var home_collision: CollisionPolygon2D = get_node_or_null("Home/Homebody/CollisionPolygon2D") as CollisionPolygon2D
@onready var home_inside_collision: CollisionPolygon2D = _get_interior_node("HomeInside/HomeInsideBody/CollisionPolygon2D") as CollisionPolygon2D
@onready var home_inside_floor_collision: CollisionShape2D = _get_interior_node("HomeInside/HomeInsideBody/Floor") as CollisionShape2D
@onready var door_location: Marker2D = _find_marker("door_location") as Marker2D
@onready var interior_arrival_from_raintree: Marker2D = _find_marker("InteriorArrivalFromRainTree") as Marker2D
@onready var interior_camera_center: Marker2D = _find_marker("TownInteriorCameraCenter") as Marker2D


func _ready() -> void:
	if home == null or home_inside == null:
		push_error("ForegroundMask is missing Home or HomeInside nodes.")
		set_process(false)
		return
	if door_location == null:
		push_error("ForegroundMask is missing door_location.")
		set_process(false)
		return

	_find_player()
	_apply_outside_visual_state()
	_set_clock_interaction_feedback(false)


func _exit_tree() -> void:
	_set_player_input_locked(false)


func _process(_delta: float) -> void:
	if player == null:
		_find_player()
		return
	if is_title_room_preview:
		return
	if map_overlay != null:
		_set_player_input_locked(true)

	var should_be_inside := _is_player_inside_side()
	if should_be_inside != is_inside_home:
		_set_home_state(should_be_inside)

	_update_clock_interaction_feedback()


func _physics_process(_delta: float) -> void:
	if is_title_room_preview:
		return
	if map_overlay != null:
		_set_player_input_locked(true)


func _unhandled_input(event: InputEvent) -> void:
	if is_title_room_preview:
		return

	if map_overlay != null:
		if event.is_action_pressed("ui_cancel"):
			_request_close_map_overlay()
			_mark_input_handled()
		return

	if not is_inside_home or is_transitioning or is_camera_transitioning:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and _is_player_near_clock():
			_open_map_overlay()
			_mark_input_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_E and _is_player_near_clock():
			_open_map_overlay()
			_mark_input_handled()


func _find_player() -> void:
	var body := get_parent().get_node_or_null("Player")
	if body == null:
		return

	if not body is CharacterBody2D:
		return

	var body_min_x = body.get("min_x")
	var body_max_x = body.get("max_x")
	if body_min_x == null or body_max_x == null:
		return

	player = body as CharacterBody2D
	camera_controller = get_parent().get_node_or_null("TownCameraController") as TownCameraController
	_read_player_half_width()

	if not has_player_world_bounds:
		player_world_min_x = float(body_min_x)
		player_world_max_x = float(body_max_x)
		has_player_world_bounds = true


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _set_home_state(inside: bool) -> void:
	if is_transitioning or player == null:
		return
	if is_route_exit_requested:
		return

	has_title_room_camera_override = false
	is_transitioning = true
	is_inside_home = inside

	if home_collision != null:
		home_collision.disabled = is_inside_home
	if home_inside_collision != null:
		home_inside_collision.disabled = not is_inside_home
	if home_inside_floor_collision != null:
		home_inside_floor_collision.disabled = not is_inside_home
	_apply_player_bounds()
	if not is_inside_home and skip_next_outside_camera_transition:
		skip_next_outside_camera_transition = false
		_apply_camera_state_immediate(false)
	else:
		_apply_camera_state()
	_start_visual_transition()


func get_interior_transition_state(destination_key: String) -> Dictionary:
	if destination_key != "raintree":
		return {}
	if player == null:
		_find_player()
	if player == null or interior_room == null:
		return {}

	var local_position: Vector2 = interior_room.to_local(player.global_position)
	return {
		"interior_local_x": local_position.x,
	}


func prepare_for_arrival(from_key: String, arrival_state: Dictionary = {}) -> void:
	if from_key != "raintree":
		return

	if player == null:
		_find_player()
	if player == null:
		return
	if interior_arrival_from_raintree == null:
		push_warning("ForegroundMask is missing InteriorArrivalFromRainTree.")
		return

	if visual_tween != null:
		visual_tween.kill()
		visual_tween = null
	_cancel_camera_transition()

	is_transitioning = false
	is_camera_transitioning = false
	is_route_exit_requested = false
	is_inside_home = true
	has_title_room_camera_override = false
	changer_node_name = "home"

	if player.has_method("set_input_locked"):
		player.call("set_input_locked", false)
	player.velocity = Vector2.ZERO
	player.global_position = interior_arrival_from_raintree.global_position.round()
	_apply_arrival_relative_x(arrival_state)
	player.reset_physics_interpolation()

	if home_collision != null:
		home_collision.disabled = true
	if home_inside_collision != null:
		home_inside_collision.disabled = false
	if home_inside_floor_collision != null:
		home_inside_floor_collision.disabled = false
	_apply_player_bounds()
	_apply_inside_visual_state()
	_apply_camera_state_immediate(true)


func prepare_transition_preview_from(source_foreground: Node) -> void:
	if source_foreground == null:
		return

	_find_player()
	var source_player := source_foreground.get_parent().get_node_or_null("Player") as CharacterBody2D
	if player != null and source_player != null:
		player.global_position = source_player.global_position
		player.velocity = source_player.velocity
		player.reset_physics_interpolation()

	is_transitioning = false
	is_camera_transitioning = false
	is_route_exit_requested = false
	is_inside_home = bool(source_foreground.get("is_inside_home"))
	changer_node_name = String(source_foreground.get("changer_node_name"))

	if home_collision != null:
		home_collision.disabled = is_inside_home
	if home_inside_collision != null:
		home_inside_collision.disabled = not is_inside_home
	if home_inside_floor_collision != null:
		home_inside_floor_collision.disabled = not is_inside_home
	_apply_player_bounds()
	if is_inside_home:
		_apply_inside_visual_state()
		_apply_camera_state_immediate(true)
	else:
		_apply_outside_visual_state()
		_apply_camera_state_immediate(false)
	_set_player_input_locked(true)


func show_title_room_state() -> void:
	if visual_tween != null:
		visual_tween.kill()
		visual_tween = null
	_cancel_camera_transition()

	is_title_room_preview = true
	is_transitioning = false
	is_camera_transitioning = false
	is_route_exit_requested = false
	is_inside_home = true
	is_camera_inside_view = true
	has_title_room_camera_override = false
	_set_clock_interaction_feedback(false)

	if home_collision != null:
		home_collision.disabled = true
	if home_inside_collision != null:
		home_inside_collision.disabled = false
	if home_inside_floor_collision != null:
		home_inside_floor_collision.disabled = false
	_apply_inside_visual_state()


func finish_title_room_to_inside_state(camera_center: Vector2, camera_zoom: Vector2) -> void:
	if visual_tween != null:
		visual_tween.kill()
		visual_tween = null
	_cancel_camera_transition()

	is_title_room_preview = false
	is_transitioning = false
	is_camera_transitioning = false
	is_route_exit_requested = false
	is_inside_home = true
	is_camera_inside_view = true
	skip_next_outside_camera_transition = true
	has_title_room_camera_override = true
	title_room_camera_override = camera_center.round()
	_set_clock_interaction_feedback(false)

	if home_collision != null:
		home_collision.disabled = true
	if home_inside_collision != null:
		home_inside_collision.disabled = false
	if home_inside_floor_collision != null:
		home_inside_floor_collision.disabled = false
	_apply_player_bounds()
	_apply_inside_visual_state()

	if camera_controller != null:
		camera_controller.enter_indoor_mode(
			true,
			title_room_camera_override,
			camera_zoom,
			true
		)


func restore_title_room_to_outside_state() -> void:
	is_title_room_preview = false
	is_transitioning = false
	is_camera_transitioning = false
	is_route_exit_requested = false
	is_camera_inside_view = false
	has_title_room_camera_override = false
	_apply_outside_visual_state()


func _apply_arrival_relative_x(arrival_state: Dictionary) -> void:
	if player == null or interior_room == null:
		return
	if not arrival_state.has("interior_local_x"):
		return

	var local_x := float(arrival_state["interior_local_x"])
	var target_global_x := interior_room.to_global(Vector2(local_x, 0.0)).x
	player.global_position.x = target_global_x


func _is_player_inside_side() -> bool:
	var door_x: float = door_location.global_position.x + DOOR_SWITCH_X_OFFSET
	var player_left_x: float = player.global_position.x - player_half_width

	if is_inside_home:
		return player_left_x < door_x + DOOR_SWITCH_PADDING

	return player_left_x < door_x


func _is_mouse_over_clock() -> bool:
	if clock == null or clock.texture == null:
		return false

	return _clock_global_rect().has_point(get_global_mouse_position())


func _is_player_near_clock() -> bool:
	if player == null or clock == null or clock.texture == null:
		return false

	var clock_rect := _clock_global_rect()
	if player.global_position.x < clock_rect.position.x or player.global_position.x > clock_rect.end.x:
		return false

	var interaction_top := clock_rect.position.y
	var interaction_bottom := clock_rect.end.y + CLOCK_INTERACT_DISTANCE
	return player.global_position.y >= interaction_top and player.global_position.y <= interaction_bottom


func _clock_global_rect() -> Rect2:
	var local_rect := clock.get_rect()
	var top_left := clock.to_global(local_rect.position)
	var top_right := clock.to_global(local_rect.position + Vector2(local_rect.size.x, 0.0))
	var bottom_left := clock.to_global(local_rect.position + Vector2(0.0, local_rect.size.y))
	var bottom_right := clock.to_global(local_rect.end)
	var min_x := minf(minf(top_left.x, top_right.x), minf(bottom_left.x, bottom_right.x))
	var min_y := minf(minf(top_left.y, top_right.y), minf(bottom_left.y, bottom_right.y))
	var max_x := maxf(maxf(top_left.x, top_right.x), maxf(bottom_left.x, bottom_right.x))
	var max_y := maxf(maxf(top_left.y, top_right.y), maxf(bottom_left.y, bottom_right.y))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _update_clock_interaction_feedback() -> void:
	var is_available := (
		is_inside_home
		and not is_transitioning
		and not is_camera_transitioning
		and map_overlay == null
	)
	_set_clock_interaction_feedback(is_available and _is_player_near_clock())


func _set_clock_interaction_feedback(active: bool) -> void:
	if clock != null:
		clock.self_modulate = CLOCK_NEAR_MODULATE if active else CLOCK_DEFAULT_MODULATE
	_set_interaction_reminder(active, CLOCK_INTERACTION_MESSAGE)


func _set_interaction_reminder(active: bool, message: String) -> void:
	if not is_inside_tree():
		return

	var reminder_manager := _interaction_reminder_manager(active)
	if reminder_manager == null:
		return
	if active:
		reminder_manager.call("show_interaction", self, message)
	else:
		reminder_manager.call("hide_interaction", self)


func _interaction_reminder_manager(create_if_missing: bool = true) -> Node:
	if interaction_reminder_manager != null and is_instance_valid(interaction_reminder_manager):
		return interaction_reminder_manager

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var existing := parent.get_node_or_null("InteractionReminderManager")
	if existing != null:
		interaction_reminder_manager = existing
		return interaction_reminder_manager
	if not create_if_missing:
		return null

	interaction_reminder_manager = INTERACTION_REMINDER_MANAGER_SCRIPT.new() as Node
	interaction_reminder_manager.name = "InteractionReminderManager"
	parent.add_child(interaction_reminder_manager)
	return interaction_reminder_manager


func _open_map_overlay() -> void:
	if map_overlay != null:
		return

	is_map_destination_committing = false
	_set_clock_interaction_feedback(false)
	_set_player_input_locked(true)

	map_overlay = CanvasLayer.new()
	map_overlay.name = "ClockMapOverlay"
	map_overlay.layer = MAP_OVERLAY_LAYER
	add_child(map_overlay)

	map_overlay_content = Node2D.new()
	map_overlay_content.name = "MapOverlayContent"
	map_overlay_content.modulate.a = 0.0
	map_overlay.add_child(map_overlay_content)

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0, 0, 0, 0.2)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay_content.add_child(dimmer)

	map_instance = MAP_SCENE.instantiate()
	map_instance.set("path_nodes", ["home", "point1"])
	var current_node := _current_map_node_name()
	var route_nodes: Array = map_instance.get("path_nodes")
	var index: int = route_nodes.find(current_node)
	if index != -1:
		map_instance.set("current_index", index)
	if map_instance.has_signal("destination_changed"):
		map_instance.connect("destination_changed", _on_map_destination_changed)
	if map_instance.has_signal("route_progress_changed"):
		map_instance.connect("route_progress_changed", _on_map_route_progress_changed)
	if map_instance.has_signal("route_return_finished"):
		map_instance.connect("route_return_finished", _on_map_route_return_finished)
	map_overlay_content.add_child(map_instance)
	if map_instance.has_method("set_current_node"):
		map_instance.call_deferred("set_current_node", current_node)
	_fade_map_overlay_to(1.0)


func _request_close_map_overlay() -> void:
	if map_overlay == null:
		return

	if is_instance_valid(map_instance) and map_instance.has_method("request_close"):
		var can_close := bool(map_instance.call("request_close"))
		if not can_close:
			is_map_close_waiting_for_return = true
			return

	_close_map_overlay()


func _close_map_overlay(unlock_player := true, reset_preview := true) -> void:
	_close_map_overlay_deferred(unlock_player, reset_preview)


func _close_map_overlay_deferred(unlock_player := true, reset_preview := true) -> void:
	if map_overlay == null:
		return

	var fade_target := _map_overlay_fade_target()
	if fade_target == null:
		map_overlay.queue_free()
		map_overlay = null
		map_overlay_content = null
		map_instance = null
		is_map_close_waiting_for_return = false
		return
	if map_overlay_tween != null:
		map_overlay_tween.kill()
	map_overlay_tween = create_tween()
	map_overlay_tween.set_trans(Tween.TRANS_SINE)
	map_overlay_tween.set_ease(Tween.EASE_OUT)
	map_overlay_tween.tween_property(fade_target, "modulate:a", 0.0, MAP_OVERLAY_FADE_DURATION)
	await map_overlay_tween.finished
	map_overlay_tween = null

	if map_overlay == null:
		return
	map_overlay.queue_free()
	map_overlay = null
	map_overlay_content = null
	map_instance = null
	is_map_close_waiting_for_return = false
	if reset_preview:
		is_map_destination_committing = false
		interior_transition_progress_changed.emit("", 0.0)
	if unlock_player:
		_set_player_input_locked(false)


func _fade_map_overlay_to(target_alpha: float) -> void:
	var fade_target := _map_overlay_fade_target()
	if fade_target == null:
		return
	if map_overlay_tween != null:
		map_overlay_tween.kill()

	map_overlay_tween = create_tween()
	map_overlay_tween.set_trans(Tween.TRANS_SINE)
	map_overlay_tween.set_ease(Tween.EASE_OUT)
	map_overlay_tween.tween_property(fade_target, "modulate:a", target_alpha, MAP_OVERLAY_FADE_DURATION)
	map_overlay_tween.finished.connect(func() -> void:
		map_overlay_tween = null
	)


func _map_overlay_fade_target() -> CanvasItem:
	return map_overlay_content


func _on_map_route_return_finished() -> void:
	if is_map_close_waiting_for_return:
		_close_map_overlay()


func _on_map_route_progress_changed(from_node: String, to_node: String, _from_index: int, _to_index: int, progress: float) -> void:
	if is_map_destination_committing and progress <= 0.001:
		return

	var destination_key := _destination_key_for_node(to_node)
	if destination_key.is_empty() and progress <= 0.001:
		interior_transition_progress_changed.emit("", 0.0)
		return
	if destination_key.is_empty():
		return

	interior_transition_progress_changed.emit(destination_key, progress)


func _on_map_destination_changed(from_node: String, to_node: String, from_index: int, to_index: int) -> void:
	changer_node_name = to_node
	changer_transition_requested.emit(from_node, to_node, from_index, to_index)
	var destination_key := _destination_key_for_node(to_node)
	if destination_key == "raintree":
		is_map_destination_committing = true
		await _close_map_overlay_deferred(false, false)
		_request_destination_scene(destination_key)
	elif destination_key.is_empty():
		is_map_destination_committing = false
		await _close_map_overlay_deferred(true, true)
		changer_node_name = "home"
	else:
		push_warning("Unknown changer destination: %s" % destination_key)


func _set_player_input_locked(locked: bool) -> void:
	if is_instance_valid(player) and player.has_method("set_input_locked"):
		player.call("set_input_locked", locked)


func _destination_key_for_node(node_name: String) -> String:
	if not NODE_DESTINATIONS.has(node_name):
		return "unknown:%s" % node_name
	return String(NODE_DESTINATIONS[node_name])


func _current_map_node_name() -> String:
	return changer_node_name


func _request_destination_scene(destination_key: String) -> void:
	if is_route_exit_requested:
		return

	is_route_exit_requested = true
	_set_clock_interaction_feedback(false)
	_set_player_input_locked(true)
	interior_exit_to_destination.emit(destination_key)


func _get_interior_node(node_path: String) -> Node:
	if interior_room != null:
		var nested_node := interior_room.get_node_or_null(node_path)
		if nested_node != null:
			return nested_node

	return get_node_or_null(node_path)


func _find_marker(marker_name: String) -> Node2D:
	var node: Node = find_child(marker_name, true, false)
	return node as Node2D


func _read_player_half_width() -> void:
	var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return

	var rectangle := collision.shape as RectangleShape2D
	if rectangle == null:
		return

	player_half_width = rectangle.size.x * 0.5


func _apply_player_bounds() -> void:
	if player == null:
		return

	if is_inside_home:
		player.set("min_x", INTERIOR_MIN_X)
		player.set("max_x", INTERIOR_MAX_X)
		player.global_position.x = clampf(player.global_position.x, INTERIOR_MIN_X, INTERIOR_MAX_X)
	elif has_player_world_bounds:
		player.set("min_x", player_world_min_x)
		player.set("max_x", player_world_max_x)


func _apply_camera_state() -> void:
	if camera_controller == null:
		_find_player()
	if camera_controller == null:
		push_warning("ForegroundMask could not find TownCameraController.")
		is_camera_transitioning = false
		return

	_disconnect_camera_transition_signal()
	is_camera_transitioning = true
	camera_controller.transition_finished.connect(_on_camera_transition_finished, CONNECT_ONE_SHOT)
	if is_inside_home:
		is_camera_inside_view = true
		camera_controller.enter_indoor_mode(false)
	else:
		is_camera_inside_view = false
		camera_controller.enter_outdoor_mode(false)


func _apply_camera_state_immediate(inside: bool) -> void:
	if camera_controller == null:
		_find_player()
	if camera_controller == null:
		push_warning("ForegroundMask could not find TownCameraController.")
		return

	_cancel_camera_transition()
	is_camera_transitioning = false
	if inside:
		is_camera_inside_view = true
		camera_controller.enter_indoor_mode(true)
	else:
		is_camera_inside_view = false
		camera_controller.enter_outdoor_mode(true)


func _on_camera_transition_finished(_mode: int) -> void:
	is_camera_transitioning = false


func _interior_camera_center() -> Vector2:
	if has_title_room_camera_override:
		return title_room_camera_override
	if interior_camera_center != null:
		return interior_camera_center.global_position
	return home_inside.global_position + INTERIOR_CAMERA_OFFSET


func _cancel_camera_transition() -> void:
	_disconnect_camera_transition_signal()
	if camera_controller != null:
		camera_controller.cancel_transition()
	is_camera_transitioning = false


func _disconnect_camera_transition_signal() -> void:
	if camera_controller == null:
		return
	if camera_controller.transition_finished.is_connected(_on_camera_transition_finished):
		camera_controller.transition_finished.disconnect(_on_camera_transition_finished)


func _setup_transition_material() -> void:
	home_transition_material = ShaderMaterial.new()
	home_transition_material.shader = MOSAIC_DISSOLVE_SHADER
	home_transition_material.set_shader_parameter("from_texture", HOME_TEXTURE)
	home_transition_material.set_shader_parameter("to_texture", HOME_TEXTURE)
	home_transition_material.set_shader_parameter("from_alpha_multiplier", 1.0 if is_inside_home else 0.0)
	home_transition_material.set_shader_parameter("to_alpha_multiplier", 0.0 if is_inside_home else 1.0)
	home.material = home_transition_material

	if home_inside_shadow != null:
		home_inside_shadow_transition_material = ShaderMaterial.new()
		home_inside_shadow_transition_material.shader = MOSAIC_DISSOLVE_SHADER
		home_inside_shadow_transition_material.set_shader_parameter("from_texture", HOME_INSIDE_SHADOW_TEXTURE)
		home_inside_shadow_transition_material.set_shader_parameter("to_texture", HOME_INSIDE_SHADOW_TEXTURE)
		home_inside_shadow_transition_material.set_shader_parameter("from_alpha_multiplier", 0.0 if is_inside_home else 1.0)
		home_inside_shadow_transition_material.set_shader_parameter("to_alpha_multiplier", 1.0 if is_inside_home else 0.0)
		home_inside_shadow.material = home_inside_shadow_transition_material
	_set_transition_progress(0.0)


func _start_visual_transition() -> void:
	if visual_tween != null:
		visual_tween.kill()

	home.texture = HOME_TEXTURE
	home.material = null
	home.visible = true
	home_inside.texture = HOME_INSIDE_TEXTURE
	home_inside.visible = true

	if home_inside_shadow != null:
		home_inside_shadow.texture = HOME_INSIDE_SHADOW_TEXTURE
		home_inside_shadow.material = null
		home_inside_shadow.modulate.a = 1.0
		home_inside_shadow.visible = true

	_setup_transition_material()
	_set_transition_progress(0.0)
	var target_progress: float = 1.0
	visual_tween = create_tween()
	visual_tween.set_trans(Tween.TRANS_SINE)
	visual_tween.set_ease(Tween.EASE_IN_OUT)
	visual_tween.tween_method(_set_transition_progress, 0.0, target_progress, VISUAL_TRANSITION_DURATION)
	visual_tween.finished.connect(_on_visual_transition_finished)


func _set_transition_progress(progress: float) -> void:
	if home_transition_material == null:
		return

	home_transition_material.set_shader_parameter("progress", progress)
	if home_inside_shadow_transition_material != null:
		home_inside_shadow_transition_material.set_shader_parameter("progress", progress)


func _on_visual_transition_finished() -> void:
	if is_inside_home:
		_apply_inside_visual_state()
	else:
		_apply_outside_visual_state()

	home.material = null
	home_transition_material = null
	if home_inside_shadow != null:
		home_inside_shadow.material = null
	home_inside_shadow_transition_material = null
	is_transitioning = false


func _apply_inside_visual_state() -> void:
	home.visible = false
	home.modulate.a = 1.0
	home.material = null
	home_inside.visible = true
	home_inside.modulate.a = 1.0
	if home_inside_shadow != null:
		home_inside_shadow.visible = true
		home_inside_shadow.modulate.a = 1.0
		home_inside_shadow.material = null


func _apply_outside_visual_state() -> void:
	is_inside_home = false
	has_title_room_camera_override = false
	_set_clock_interaction_feedback(false)
	home.texture = HOME_TEXTURE
	home.visible = true
	home.modulate.a = 1.0
	home.material = null
	if home_collision != null:
		home_collision.disabled = false
	home_inside.texture = HOME_INSIDE_TEXTURE
	home_inside.visible = false
	home_inside.modulate.a = 1.0
	if home_inside_shadow != null:
		home_inside_shadow.visible = false
		home_inside_shadow.modulate.a = 1.0
		home_inside_shadow.material = null
	if home_inside_collision != null:
		home_inside_collision.disabled = true
	if home_inside_floor_collision != null:
		home_inside_floor_collision.disabled = true
