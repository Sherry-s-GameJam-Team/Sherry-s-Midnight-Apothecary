extends Node2D

signal interior_exit_to_destination(destination_key: String)
signal room_access_enabled_changed(enabled: bool)
signal interior_transition_progress_changed(destination_key: String, progress: float)

const LAYER_SCROLL_FACTORS := {
	"DistantScenery": 0.30,
	"Middle": 0.55,
}
const MAP_SCENE = preload("res://game/main/scenes/doorchanger/map.tscn")
const INTERACTION_REMINDER_MANAGER_SCRIPT = preload("res://game/src/system/reminder/interaction_reminder_manager.gd")
const CAMERA_LIMIT_LEFT := -2172
const CAMERA_LIMIT_TOP := -2250
const CAMERA_LIMIT_RIGHT := 4344
const CAMERA_LIMIT_BOTTOM := 724
const ROOM_VISUAL_TRANSITION_DURATION := 0.45
const ROOM_INTERIOR_BASE_Z_INDEX := 10
const ROOM_INTERIOR_ACTIVE_Z_INDEX := 15
const ROOM_DOOR_SWITCH_PADDING := 10.0
const PLAYER_LIMIT_LEFT := -2110.0
const PLAYER_LIMIT_TOP := -2250.0
const PLAYER_LIMIT_RIGHT := 4280.0
const PLAYER_LIMIT_BOTTOM := 648.0
const ROOM_INTERIOR_FALLBACK_HALF_WIDTH := 430.0
const DEFAULT_PLAYER_HALF_WIDTH := 24.0
const SKYBOX_TOP_RESERVE_RATIO := 0.25
const SKYBOX_TEXTURE_HEIGHT := 1275.0
const CHANGER_INTERACT_DISTANCE := 120.0
const CHANGER_INTERACTION_MESSAGE := "按下 E 打开地图"
const CHANGER_NEAR_MODULATE := Color(0.58, 0.58, 0.58, 1.0)
const CHANGER_DEFAULT_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const MAP_OVERLAY_LAYER := 130
const MAP_OVERLAY_FADE_DURATION := 0.18
const NODE_DESTINATIONS := {
	"home": "town",
	"point1": "",
}

var is_inside_room := false
var is_room_access_enabled := false
var is_room_transitioning := false
var is_room_camera_transitioning := false
var is_room_camera_inside_view := false
var is_route_exit_requested := false
var camera_anchor := Vector2.ZERO
var skybox_origin := Vector2.ZERO
var skybox_content_top := 0.0
var skybox: Node2D = null
var layer_origins := {}
var parallax_layers := {}
var player_body: CharacterBody2D = null
var player_world_min_x := PLAYER_LIMIT_LEFT
var player_world_max_x := PLAYER_LIMIT_RIGHT
var player_half_width := DEFAULT_PLAYER_HALF_WIDTH
var room_visual_tween: Tween = null
var map_overlay_tween: Tween = null
var has_player_world_bounds := false
var map_overlay: CanvasLayer = null
var map_overlay_content: Node2D = null
var map_instance: Node = null
var interaction_reminder_manager: Node = null
var changer_node_name := "point1"
var hide_room_after_arrival_exit := false
var is_map_close_waiting_for_return := false
var is_map_destination_committing := false
var has_shown_arrival_outside_title := false

@onready var camera: Camera2D = get_node_or_null("Player/Camera2D") as Camera2D
@onready var camera_controller: TownCameraController = get_node_or_null("TownCameraController") as TownCameraController
@onready var room_interior: Node2D = get_node_or_null("RoomInteriorHost") as Node2D
@onready var room_shader: Sprite2D = get_node_or_null("ForegroundMask/RoomShader") as Sprite2D
@onready var room_collision: CollisionPolygon2D = get_node_or_null("Ground/GroundBody/CollisionPolygon2D") as CollisionPolygon2D
@onready var room_door_location: Marker2D = get_node_or_null("RoomDoorLocation") as Marker2D
@onready var room_interior_camera_center: Marker2D = get_node_or_null("RoomInteriorCameraCenter") as Marker2D
@onready var room_interior_collision: CollisionPolygon2D = get_node_or_null("RoomInteriorHost/HomeInside/HomeInsideBody/CollisionPolygon2D") as CollisionPolygon2D
@onready var room_interior_floor_collision: CollisionShape2D = get_node_or_null("RoomInteriorHost/HomeInside/HomeInsideBody/Floor") as CollisionShape2D
@onready var room_interior_shadow: Sprite2D = get_node_or_null("RoomInteriorHost/HomeInsideShadow") as Sprite2D
@onready var interior_room_leaf_host: Node2D = get_node_or_null("RoomInteriorHost/HomeInside/RoomLeafHost") as Node2D
@onready var town_room_leaf: Sprite2D = get_node_or_null("RoomInteriorHost/HomeInside/RoomLeafHost/TownRoomLeaf") as Sprite2D
@onready var raintree_room_leaf: Sprite2D = get_node_or_null("RoomInteriorHost/HomeInside/RoomLeafHost/RainTreeRoomLeaf") as Sprite2D
@onready var changer: Sprite2D = get_node_or_null("RoomInteriorHost/HomeInside/Clock") as Sprite2D
@onready var startup_interactable: Node = get_node_or_null("StartupInteractable")
@onready var title_reveal_demo: Node = get_node_or_null("TitleRevealDemo")


func _ready() -> void:
	player_body = get_node_or_null("Player") as CharacterBody2D
	_read_player_half_width()
	if startup_interactable != null and startup_interactable.has_method("set_player"):
		startup_interactable.call("set_player", player_body)
	_connect_startup_interactable_signals()
	_apply_room_leaf_variant()
	_set_changer_interaction_feedback(false)
	set_room_access_enabled(false)

	if camera == null:
		camera = get_viewport().get_camera_2d()
	if camera == null:
		set_process(false)
		return
	if camera_controller == null:
		push_error("RainTree requires a TownCameraController.")

	_apply_scene_limits()
	camera_anchor = camera.get_screen_center_position()

	skybox = get_node_or_null("Skybox") as Node2D
	if skybox != null:
		skybox_origin = skybox.global_position
		skybox_content_top = _skybox_content_top()

	for layer_name in LAYER_SCROLL_FACTORS:
		var layer := get_node_or_null(layer_name) as Node2D
		if layer == null:
			continue
		parallax_layers[layer_name] = layer

	for layer_name in parallax_layers:
		layer_origins[layer_name] = (parallax_layers[layer_name] as Node2D).global_position

	_apply_initial_room_state()
	_update_parallax_layers()


func _process(_delta: float) -> void:
	if camera == null:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return
	if map_overlay != null:
		_set_player_input_locked(true)
	_update_room_transition()
	_update_changer_interaction_feedback()
	_update_startup_interactable_state()
	_update_parallax_layers()


func _physics_process(_delta: float) -> void:
	if map_overlay != null:
		_set_player_input_locked(true)


func _exit_tree() -> void:
	_set_player_input_locked(false)


func _unhandled_input(event: InputEvent) -> void:
	if map_overlay != null:
		if event.is_action_pressed("ui_cancel"):
			_request_close_map_overlay()
			_mark_input_handled()
		return

	if not is_inside_room or is_room_transitioning or is_room_camera_transitioning or is_route_exit_requested:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and _is_player_near_changer():
			_open_map_overlay()
			_mark_input_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_E and _is_player_near_changer():
			_open_map_overlay()
			_mark_input_handled()


func _update_room_transition() -> void:
	if player_body == null:
		player_body = get_node_or_null("Player") as CharacterBody2D
		_read_player_half_width()
	if player_body == null or room_door_location == null:
		return
	if not is_room_access_enabled:
		return

	var should_be_inside: bool = _is_player_inside_room_side()
	if should_be_inside != is_inside_room:
		_set_room_state(should_be_inside)


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _is_player_inside_room_side() -> bool:
	if not is_room_access_enabled:
		return false

	var door_x: float = _room_door_switch_x()
	var player_left_x: float = player_body.global_position.x - player_half_width

	if is_inside_room:
		return player_left_x < door_x + ROOM_DOOR_SWITCH_PADDING

	return player_left_x < door_x


func _set_room_state(inside: bool) -> void:
	if is_room_transitioning or player_body == null:
		return
	if inside and not is_room_access_enabled:
		return

	is_room_transitioning = true
	is_inside_room = inside
	_sync_room_collision_state()
	if room_interior_collision != null:
		room_interior_collision.disabled = not is_inside_room
	if room_interior_floor_collision != null:
		room_interior_floor_collision.disabled = not is_inside_room
	_apply_player_bounds()
	_apply_room_camera_state()
	_start_room_visual_transition()


func get_interior_transition_state(destination_key: String) -> Dictionary:
	if destination_key != "town":
		return {}
	if player_body == null:
		player_body = get_node_or_null("Player") as CharacterBody2D
		_read_player_half_width()
	if player_body == null or room_interior == null:
		return {}

	var local_position: Vector2 = room_interior.to_local(player_body.global_position)
	return {
		"interior_local_x": local_position.x,
	}


func prepare_for_arrival(from_key: String, arrival_state: Dictionary = {}) -> void:
	if from_key != "town":
		return

	if player_body == null:
		player_body = get_node_or_null("Player") as CharacterBody2D
		_read_player_half_width()
	if player_body == null:
		return

	if room_visual_tween != null:
		room_visual_tween.kill()
		room_visual_tween = null
	_cancel_room_camera_transition()

	is_room_transitioning = false
	is_room_camera_transitioning = false
	is_route_exit_requested = false
	is_room_access_enabled = true
	is_inside_room = true
	hide_room_after_arrival_exit = true
	has_shown_arrival_outside_title = false
	changer_node_name = "point1"

	_set_player_input_locked(false)
	player_body.velocity = Vector2.ZERO
	player_body.global_position = _room_arrival_position_from_town().round()
	_apply_arrival_relative_x(arrival_state)
	player_body.reset_physics_interpolation()
	_apply_player_bounds()
	_apply_room_inside_visual_state()
	_apply_room_camera_state_immediate(true)
	_update_startup_interactable_state()
	room_access_enabled_changed.emit(is_room_access_enabled)


func prepare_transition_preview_from(source_scene: Node) -> void:
	if source_scene == null:
		return

	if player_body == null:
		player_body = get_node_or_null("Player") as CharacterBody2D
		_read_player_half_width()
	var source_player := source_scene.get_node_or_null("Player") as CharacterBody2D
	if player_body != null and source_player != null:
		player_body.global_position = source_player.global_position
		player_body.velocity = source_player.velocity
		player_body.reset_physics_interpolation()

	if room_visual_tween != null:
		room_visual_tween.kill()
		room_visual_tween = null
	_cancel_room_camera_transition()

	is_room_transitioning = false
	is_room_camera_transitioning = false
	is_route_exit_requested = false
	is_room_access_enabled = bool(source_scene.get("is_room_access_enabled"))
	is_inside_room = bool(source_scene.get("is_inside_room"))
	hide_room_after_arrival_exit = bool(source_scene.get("hide_room_after_arrival_exit"))
	has_shown_arrival_outside_title = bool(source_scene.get("has_shown_arrival_outside_title"))
	changer_node_name = String(source_scene.get("changer_node_name"))

	_apply_player_bounds()
	if is_inside_room:
		_apply_room_inside_visual_state()
		_apply_room_camera_state_immediate(true)
	else:
		_apply_room_outside_visual_state()
		_apply_room_camera_state_immediate(false)
	_set_player_input_locked(true)
	room_access_enabled_changed.emit(is_room_access_enabled)


func _apply_arrival_relative_x(arrival_state: Dictionary) -> void:
	if player_body == null or room_interior == null:
		return
	if not arrival_state.has("interior_local_x"):
		return

	var local_x := float(arrival_state["interior_local_x"])
	var target_global_x := room_interior.to_global(Vector2(local_x, 0.0)).x
	player_body.global_position.x = target_global_x


func _apply_initial_room_state() -> void:
	if player_body == null or room_door_location == null:
		_apply_room_outside_visual_state()
		return
	if not is_room_access_enabled:
		is_inside_room = false
		_apply_player_bounds()
		_apply_room_outside_visual_state()
		_apply_room_camera_state_immediate(false)
		return

	is_inside_room = _is_player_inside_room_side()
	if is_inside_room:
		_apply_player_bounds()
		_apply_room_inside_visual_state()
		_apply_room_camera_state_immediate(true)
	else:
		_apply_room_outside_visual_state()
		_apply_room_camera_state_immediate(false)


func _apply_room_leaf_variant() -> void:
	if interior_room_leaf_host != null:
		interior_room_leaf_host.z_index = 40

	if town_room_leaf != null:
		var town_color: Color = town_room_leaf.modulate
		town_color.a = 0.0
		town_room_leaf.modulate = town_color
		town_room_leaf.visible = false

	if raintree_room_leaf != null:
		var rain_color: Color = raintree_room_leaf.modulate
		rain_color.a = 1.0
		raintree_room_leaf.modulate = rain_color
		raintree_room_leaf.visible = true


func set_room_access_enabled(enabled: bool) -> void:
	if is_room_access_enabled == enabled:
		_apply_room_access_state()
		return

	is_room_access_enabled = enabled
	_apply_room_access_state()
	room_access_enabled_changed.emit(is_room_access_enabled)


func _apply_room_access_state() -> void:
	_sync_room_collision_state()
	if room_interior_collision != null and not is_inside_room:
		room_interior_collision.disabled = true
	if room_interior_floor_collision != null and not is_inside_room:
		room_interior_floor_collision.disabled = true

	if is_room_access_enabled:
		if not is_inside_room and not is_room_transitioning:
			_apply_room_outside_visual_state()
		return

	if is_inside_room and not is_room_transitioning:
		_set_room_state(false)
		return

	if not is_room_transitioning:
		_apply_room_outside_visual_state()


func _sync_room_collision_state() -> void:
	if room_collision != null:
		room_collision.disabled = not is_room_access_enabled or is_inside_room


func _update_changer_interaction_feedback() -> void:
	var is_available := (
		is_inside_room
		and not is_room_transitioning
		and not is_room_camera_transitioning
		and not is_route_exit_requested
		and map_overlay == null
	)
	_set_changer_interaction_feedback(is_available and _is_player_near_changer())


func _update_startup_interactable_state() -> void:
	if startup_interactable == null or not startup_interactable.has_method("set_interaction_enabled"):
		return

	var is_available := (
		not is_inside_room
		and not is_room_transitioning
		and not is_room_camera_transitioning
		and not is_route_exit_requested
		and map_overlay == null
	)
	startup_interactable.call("set_interaction_enabled", is_available)


func _connect_startup_interactable_signals() -> void:
	if startup_interactable == null:
		return

	if startup_interactable.has_signal("startup_finished"):
		var opened_callable := Callable(self, "_on_startup_interactable_opened")
		if not startup_interactable.is_connected("startup_finished", opened_callable):
			startup_interactable.connect("startup_finished", opened_callable)

	if startup_interactable.has_signal("close_finished"):
		var closed_callable := Callable(self, "_on_startup_interactable_closed")
		if not startup_interactable.is_connected("close_finished", closed_callable):
			startup_interactable.connect("close_finished", closed_callable)


func _on_startup_interactable_opened() -> void:
	hide_room_after_arrival_exit = false
	set_room_access_enabled(true)


func _on_startup_interactable_closed() -> void:
	hide_room_after_arrival_exit = false
	set_room_access_enabled(false)


func _set_changer_interaction_feedback(active: bool) -> void:
	if changer != null:
		changer.self_modulate = CHANGER_NEAR_MODULATE if active else CHANGER_DEFAULT_MODULATE
	_set_interaction_reminder(active, CHANGER_INTERACTION_MESSAGE)


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


func _is_mouse_over_changer() -> bool:
	if changer == null or changer.texture == null:
		return false

	return _changer_global_rect().has_point(get_global_mouse_position())


func _is_player_near_changer() -> bool:
	if player_body == null or changer == null or changer.texture == null:
		return false

	var changer_rect := _changer_global_rect()
	if player_body.global_position.x < changer_rect.position.x or player_body.global_position.x > changer_rect.end.x:
		return false

	var interaction_top := changer_rect.position.y
	var interaction_bottom := changer_rect.end.y + CHANGER_INTERACT_DISTANCE
	return player_body.global_position.y >= interaction_top and player_body.global_position.y <= interaction_bottom


func _changer_global_rect() -> Rect2:
	var local_rect := changer.get_rect()
	var top_left := changer.to_global(local_rect.position)
	var top_right := changer.to_global(local_rect.position + Vector2(local_rect.size.x, 0.0))
	var bottom_left := changer.to_global(local_rect.position + Vector2(0.0, local_rect.size.y))
	var bottom_right := changer.to_global(local_rect.end)
	var min_x := minf(minf(top_left.x, top_right.x), minf(bottom_left.x, bottom_right.x))
	var min_y := minf(minf(top_left.y, top_right.y), minf(bottom_left.y, bottom_right.y))
	var max_x := maxf(maxf(top_left.x, top_right.x), maxf(bottom_left.x, bottom_right.x))
	var max_y := maxf(maxf(top_left.y, top_right.y), maxf(bottom_left.y, bottom_right.y))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _open_map_overlay() -> void:
	if map_overlay != null:
		return

	is_map_destination_committing = false
	_set_changer_interaction_feedback(false)
	_set_player_input_locked(true)

	map_overlay = CanvasLayer.new()
	map_overlay.name = "HollMapOverlay"
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
	var destination_key := _destination_key_for_node(to_node)
	if destination_key == "town":
		is_map_destination_committing = true
		await _close_map_overlay_deferred(false, false)
		_request_destination_scene(destination_key)
	elif destination_key.is_empty():
		is_map_destination_committing = false
		await _close_map_overlay_deferred(true, true)
		changer_node_name = "point1"
	else:
		push_warning("Unknown changer destination: %s" % destination_key)


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
	_set_changer_interaction_feedback(false)
	_set_player_input_locked(true)
	interior_exit_to_destination.emit(destination_key)


func _set_player_input_locked(locked: bool) -> void:
	if is_instance_valid(player_body):
		player_body.velocity = Vector2.ZERO
	if is_instance_valid(player_body) and player_body.has_method("set_input_locked"):
		player_body.call("set_input_locked", locked)


func _update_parallax_layers() -> void:
	var camera_delta := camera.get_screen_center_position() - camera_anchor
	var camera_delta_x := Vector2(camera_delta.x, 0.0)

	if skybox != null:
		skybox.global_position = Vector2(
			skybox_origin.x + camera_delta.x,
			_skybox_height_for_camera(camera.get_screen_center_position().y)
		).round()

	for layer_name in parallax_layers:
		var layer := parallax_layers[layer_name] as Node2D
		if layer == null:
			continue
		var layer_origin: Vector2 = layer_origins[layer_name]
		var scroll_factor := float(LAYER_SCROLL_FACTORS[layer_name])
		layer.global_position = layer_origin + Vector2(camera_delta.x * (1.0 - scroll_factor), 0.0)


func _apply_scene_limits() -> void:
	var player: Node = get_node_or_null("Player")
	if player != null:
		player.set("min_x", PLAYER_LIMIT_LEFT)
		player.set("min_y", PLAYER_LIMIT_TOP)
		player.set("max_x", PLAYER_LIMIT_RIGHT)
		player.set("max_y", PLAYER_LIMIT_BOTTOM)
		if not has_player_world_bounds:
			player_world_min_x = PLAYER_LIMIT_LEFT
			player_world_max_x = PLAYER_LIMIT_RIGHT

	if not has_player_world_bounds:
		has_player_world_bounds = true


func _read_player_half_width() -> void:
	if player_body == null:
		return

	var collision: CollisionShape2D = player_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return

	var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
	if rectangle == null:
		return

	player_half_width = rectangle.size.x * 0.5


func _apply_player_bounds() -> void:
	if player_body == null:
		return

	if is_inside_room:
		var interior_bounds := _interior_player_x_bounds()
		player_body.set("min_x", interior_bounds.x)
		player_body.set("max_x", interior_bounds.y)
		player_body.global_position.x = clampf(player_body.global_position.x, interior_bounds.x, interior_bounds.y)
	else:
		player_body.set("min_x", player_world_min_x)
		player_body.set("max_x", player_world_max_x)


func _interior_player_x_bounds() -> Vector2:
	if room_interior_collision != null and room_interior_collision.polygon.size() > 0:
		var min_x := 0.0
		var max_x := 0.0
		var has_point := false
		for point in room_interior_collision.polygon:
			var global_point: Vector2 = room_interior_collision.to_global(point)
			if not has_point:
				min_x = global_point.x
				max_x = global_point.x
				has_point = true
				continue
			min_x = minf(min_x, global_point.x)
			max_x = maxf(max_x, global_point.x)
		if has_point:
			return _extend_interior_bounds_to_room_door_exit(Vector2(
				min_x + player_half_width,
				max_x - player_half_width
			))

	var center_x := room_interior.global_position.x if room_interior != null else 0.0
	return _extend_interior_bounds_to_room_door_exit(Vector2(
		center_x - ROOM_INTERIOR_FALLBACK_HALF_WIDTH + player_half_width,
		center_x + ROOM_INTERIOR_FALLBACK_HALF_WIDTH - player_half_width
	))


func _extend_interior_bounds_to_room_door_exit(bounds: Vector2) -> Vector2:
	if room_door_location == null:
		return bounds

	var exit_center_x := _room_door_switch_x() + ROOM_DOOR_SWITCH_PADDING + player_half_width
	return Vector2(bounds.x, maxf(bounds.y, exit_center_x))


func _room_arrival_position_from_town() -> Vector2:
	var arrival_position := player_body.global_position
	if room_door_location != null:
		var door_position: Vector2 = room_door_location.global_position
		arrival_position = door_position
		arrival_position.x = door_position.x - player_half_width - ROOM_DOOR_SWITCH_PADDING

	var interior_bounds := _interior_player_x_bounds()
	arrival_position.x = clampf(arrival_position.x, interior_bounds.x, interior_bounds.y)
	return arrival_position


func _room_door_switch_x() -> float:
	if room_door_location != null:
		return room_door_location.global_position.x
	return player_body.global_position.x if player_body != null else 0.0


func _apply_room_camera_state() -> void:
	if camera_controller == null:
		push_warning("RainTree could not find TownCameraController.")
		is_room_camera_transitioning = false
		return

	_disconnect_room_camera_transition_signal()
	is_room_camera_transitioning = true
	camera_controller.transition_finished.connect(_on_room_camera_transition_finished, CONNECT_ONE_SHOT)
	if is_inside_room:
		is_room_camera_inside_view = true
		camera_controller.enter_indoor_mode(false)
	else:
		is_room_camera_inside_view = false
		camera_controller.enter_outdoor_mode(false)


func _on_room_camera_transition_finished(_mode: int) -> void:
	is_room_camera_transitioning = false


func _apply_room_camera_state_immediate(inside: bool) -> void:
	if camera_controller == null:
		push_warning("RainTree could not find TownCameraController.")
		return

	_cancel_room_camera_transition()
	is_room_camera_transitioning = false
	if inside:
		is_room_camera_inside_view = true
		camera_controller.enter_indoor_mode(true)
	else:
		is_room_camera_inside_view = false
		camera_controller.enter_outdoor_mode(true)


func _room_interior_camera_center() -> Vector2:
	if room_interior_camera_center != null:
		return room_interior_camera_center.global_position
	if room_interior != null:
		return room_interior.global_position
	return Vector2.ZERO


func _cancel_room_camera_transition() -> void:
	_disconnect_room_camera_transition_signal()
	if camera_controller != null:
		camera_controller.cancel_transition()
	is_room_camera_transitioning = false


func _disconnect_room_camera_transition_signal() -> void:
	if camera_controller == null:
		return
	if camera_controller.transition_finished.is_connected(_on_room_camera_transition_finished):
		camera_controller.transition_finished.disconnect(_on_room_camera_transition_finished)


func _start_room_visual_transition() -> void:
	if room_visual_tween != null:
		room_visual_tween.kill()

	if room_interior != null:
		room_interior.z_index = ROOM_INTERIOR_ACTIVE_Z_INDEX
		room_interior.visible = true
	if room_interior_shadow != null:
		room_interior_shadow.visible = true

	var target_progress: float = 1.0 if is_inside_room else 0.0
	room_visual_tween = create_tween()
	room_visual_tween.set_trans(Tween.TRANS_SINE)
	room_visual_tween.set_ease(Tween.EASE_IN_OUT)
	room_visual_tween.tween_method(_set_room_visual_progress, _room_visual_progress(), target_progress, ROOM_VISUAL_TRANSITION_DURATION)
	room_visual_tween.finished.connect(_on_room_visual_transition_finished)


func _room_visual_progress() -> float:
	if room_interior == null:
		return 1.0 if is_inside_room else 0.0
	return room_interior.modulate.a


func _set_room_visual_progress(progress: float) -> void:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	if room_interior != null:
		var interior_color: Color = room_interior.modulate
		interior_color.a = clamped_progress
		room_interior.modulate = interior_color
	if room_interior_shadow != null:
		var shadow_color: Color = room_interior_shadow.modulate
		shadow_color.a = clamped_progress
		room_interior_shadow.modulate = shadow_color
	_sync_room_shader_visibility(clamped_progress)


func _sync_room_shader_visibility(room_visual_progress: float = -1.0) -> void:
	if room_shader == null:
		return

	var interior_progress := room_visual_progress
	if interior_progress < 0.0:
		interior_progress = _room_visual_progress()
	room_shader.visible = interior_progress <= 0.001


func _on_room_visual_transition_finished() -> void:
	if is_inside_room:
		_apply_room_inside_visual_state()
	else:
		var should_show_arrival_title := hide_room_after_arrival_exit and not has_shown_arrival_outside_title
		_hide_arrival_room_after_exit_if_needed()
		_apply_room_outside_visual_state()
		if should_show_arrival_title:
			_show_arrival_outside_title()
	is_room_transitioning = false


func _hide_arrival_room_after_exit_if_needed() -> void:
	if not hide_room_after_arrival_exit:
		return

	hide_room_after_arrival_exit = false
	if is_room_access_enabled:
		is_room_access_enabled = false
		room_access_enabled_changed.emit(is_room_access_enabled)


func _show_arrival_outside_title() -> void:
	has_shown_arrival_outside_title = true
	if title_reveal_demo == null:
		return
	if title_reveal_demo.has_method("play_demo"):
		title_reveal_demo.call("play_demo", 5.0)


func _apply_room_inside_visual_state() -> void:
	_set_room_visual_progress(1.0)
	_sync_room_collision_state()
	if room_interior_collision != null:
		room_interior_collision.disabled = false
	if room_interior_floor_collision != null:
		room_interior_floor_collision.disabled = false
	if room_interior != null:
		room_interior.z_index = ROOM_INTERIOR_ACTIVE_Z_INDEX
		room_interior.visible = true
	if room_interior_shadow != null:
		room_interior_shadow.visible = true
	_sync_room_shader_visibility(1.0)
	_set_changer_interaction_feedback(false)


func _apply_room_outside_visual_state() -> void:
	is_inside_room = false
	_set_room_visual_progress(0.0)
	_sync_room_collision_state()
	_set_changer_interaction_feedback(false)
	if room_interior_collision != null:
		room_interior_collision.disabled = true
	if room_interior_floor_collision != null:
		room_interior_floor_collision.disabled = true
	if room_interior != null:
		room_interior.z_index = ROOM_INTERIOR_BASE_Z_INDEX
		room_interior.visible = false
	if room_interior_shadow != null:
		room_interior_shadow.visible = false
	_sync_room_shader_visibility(0.0)


func _skybox_height_for_camera(camera_center_y: float) -> float:
	var top_center_y := _top_camera_center_y()
	var climb_progress := _inverse_lerp(camera_anchor.y, top_center_y, camera_center_y)
	var skybox_top_y := float(CAMERA_LIMIT_TOP) - (skybox_content_top + SKYBOX_TEXTURE_HEIGHT * SKYBOX_TOP_RESERVE_RATIO)

	return lerpf(skybox_origin.y, skybox_top_y, clampf(climb_progress, 0.0, 1.0))


func _top_camera_center_y() -> float:
	var viewport_height := get_viewport_rect().size.y
	var half_visible_height := viewport_height * 0.5 / camera.zoom.y

	return CAMERA_LIMIT_TOP + half_visible_height


func _inverse_lerp(from_value: float, to_value: float, value: float) -> float:
	if is_equal_approx(from_value, to_value):
		return 0.0

	return (value - from_value) / (to_value - from_value)


func _skybox_content_top() -> float:
	if skybox == null:
		return 0.0

	var has_sprite := false
	var top := 0.0
	for child in skybox.get_children():
		var sprite := child as Sprite2D
		if sprite == null:
			continue
		if not has_sprite:
			top = sprite.position.y
			has_sprite = true
			continue
		top = minf(top, sprite.position.y)

	return top if has_sprite else 0.0
