class_name PotionThrower
extends Node2D

signal projectile_spawned(projectile: PotionProjectile)

const PROJECTILE_SCENE := preload("res://shared/potions/runtime/potion_projectile.tscn")

@export var throw_tuning: PotionThrowTuning
@export var effect_tuning: PotionEffectTuning
@export var tutorial_hint_id := "tutorial_throw_potion"
@export var default_definitions: Array[PotionData] = []
@export var potion_definitions: Array[PotionData] = []

@onready var aim_origin: Node2D = (get_node_or_null("AimOrigin") as Node2D)
@onready var magic_circle: PotionMagicCircle = (get_node_or_null("AimOrigin/MagicCircle") if has_node("AimOrigin/MagicCircle") else get_node_or_null("MagicCircle")) as PotionMagicCircle
@onready var trajectory_preview: PotionTrajectoryPreview = (get_node_or_null("TrajectoryPreview") as PotionTrajectoryPreview)
@onready var camera_director: PotionCameraDirector = (get_node_or_null("CameraDirector") as PotionCameraDirector)
@onready var hotbar: PotionHotbar = (get_node_or_null("PotionHotbar") if has_node("PotionHotbar") else get_node_or_null("HotbarCanvas/PotionHotbarUI")) as PotionHotbar

var inventory_service: PotionInventoryService
var _definition_by_id: Dictionary = {}
var _aiming := false
var _casting := false
var _drag_start_mouse := Vector2.ZERO
var _pending_velocity := Vector2.ZERO
var _reservation: PotionDoseReservation
var _original_time_scale := 1.0
var _active_projectile: PotionProjectile


func _ready() -> void:
	_init_definitions()
	if throw_tuning == null:
		throw_tuning = PotionThrowTuning.new()
	if effect_tuning == null:
		effect_tuning = PotionEffectTuning.new()
	call_deferred("_connect_player_data")


func _process(_delta: float) -> void:
	if inventory_service == null:
		_connect_player_data()
	if _aiming:
		_update_aim_preview()


func _input(event: InputEvent) -> void:
	if get_tree().has_meta("day_modal_input_locked") or inventory_service == null or throw_tuning == null:
		return
	if _should_block_for_console(event):
		return
	if _aiming and event.is_action_pressed("potion_cancel"):
		cancel_aim()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
	elif _aiming and event.is_action_released("potion_aim"):
		_finish_aim()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
	elif not _aiming and not hotbar.is_detail_open():
		_handle_slot_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().has_meta("day_modal_input_locked") or inventory_service == null or throw_tuning == null:
		return
	if _should_block_for_console(event):
		return
	if not _aiming and event.is_action_pressed("potion_aim"):
		if _begin_aim():
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()


func on_cast_release() -> void:
	_casting = false
	if _reservation == null or not _reservation.active:
		return
	var potion_id := _reservation.potion_id
	var potion: PotionData = _definition_by_id.get(potion_id)
	if potion == null or potion_id == &"black_potion":
		_abort_cast()
		return
	var projectile: PotionProjectile = PROJECTILE_SCENE.instantiate()
	var container := get_parent().get_parent() if get_parent() != null and get_parent().get_parent() != null else get_tree().current_scene
	if container == null:
		_abort_cast()
		return
	container.add_child(projectile)
	projectile.global_position = aim_origin.global_position
	projectile.configure(_pending_velocity, {}, potion, throw_tuning, effect_tuning)
	var payload := inventory_service.commit_reservation(_reservation)
	_reservation = null
	if payload.is_empty():
		projectile.queue_free()
		_abort_cast()
		return
	projectile.configure(_pending_velocity, payload, potion, throw_tuning, effect_tuning)
	_active_projectile = projectile
	projectile_spawned.emit(projectile)
	projectile.broken.connect(_on_projectile_broken)
	projectile.tree_exiting.connect(_on_projectile_exiting.bind(projectile), CONNECT_ONE_SHOT)
	Engine.time_scale = throw_tuning.flight_time_scale
	magic_circle.hide_circle()
	camera_director.follow(projectile, throw_tuning)
	hotbar.close_detail()


func on_cast_animation_finished() -> void:
	_casting = false
	if _active_projectile == null and not camera_director_is_active():
		_restore_time()


func cancel_aim() -> void:
	if _reservation != null:
		inventory_service.cancel_reservation(_reservation)
		_reservation = null
	_aiming = false
	_casting = false
	trajectory_preview.hide_preview()
	magic_circle.hide_circle()
	_restore_time()


func selected_potion_id() -> StringName:
	if inventory_service == null or inventory_service.player_data == null:
		return &""
	var player_data := inventory_service.player_data
	if player_data.selected_potion_slot < 0 or player_data.selected_potion_slot >= player_data.equipped_potion_ids.size():
		return &""
	return player_data.equipped_potion_ids[player_data.selected_potion_slot]


func camera_director_is_active() -> bool:
	return camera_director != null and camera_director._active


func _begin_aim() -> bool:
	if hotbar.is_detail_open():
		return false
	var player := get_parent()
	if not player.has_method("can_start_potion_aim") or not bool(player.call("can_start_potion_aim", true)):
		return false
	var potion_id := selected_potion_id()
	if potion_id == &"" or potion_id == &"black_potion" or not _definition_by_id.has(potion_id):
		return false
	_reservation = inventory_service.reserve_dose(potion_id, throw_tuning.dose_per_throw)
	if _reservation == null:
		return false
	if camera_director != null and camera_director._active:
		camera_director.stop_follow()
	_casting = false
	_original_time_scale = 1.0
	Engine.time_scale = throw_tuning.aim_time_scale
	_aiming = true
	_show_throw_tutorial_once()
	_drag_start_mouse = get_global_mouse_position()
	_update_origin()
	var potion: PotionData = _definition_by_id[potion_id]
	var next := inventory_service.get_next_instance(potion_id)
	magic_circle.show_circle(PotionColorResolver.resolve(potion, next))
	return true


func _finish_aim() -> void:
	var drag := get_global_mouse_position() - _drag_start_mouse
	if drag.length() < throw_tuning.minimum_valid_drag_distance:
		cancel_aim()
		return
	_pending_velocity = _velocity_from_drag(drag)
	_aiming = false
	trajectory_preview.hide_preview()
	if get_parent().has_method("play_potion_cast"):
		get_parent().call("play_potion_cast")
	else:
		on_cast_release()


func _update_aim_preview() -> void:
	var drag := get_global_mouse_position() - _drag_start_mouse
	var launch_velocity := _velocity_from_drag(drag)
	if absf(launch_velocity.x) > 1.0 and get_parent().has_method("set_potion_aim_facing"):
		get_parent().call("set_potion_aim_facing", launch_velocity.x > 0.0)
	_update_origin()
	trajectory_preview.update_preview(aim_origin.global_position, launch_velocity, throw_tuning, [get_parent().get_rid()])


func _velocity_from_drag(drag: Vector2) -> Vector2:
	var distance := minf(drag.length(), throw_tuning.maximum_drag_distance)
	if distance <= 0.001:
		return Vector2.ZERO
	var ratio := distance / throw_tuning.maximum_drag_distance
	var speed := lerpf(throw_tuning.minimum_throw_speed, throw_tuning.maximum_throw_speed, ratio)
	return -drag.normalized() * speed


func _update_origin() -> void:
	var facing_right := bool(get_parent().call("is_facing_right")) if get_parent().has_method("is_facing_right") else false
	aim_origin.position = throw_tuning.aim_origin_right if facing_right else throw_tuning.aim_origin_left


func _handle_slot_input(event: InputEvent) -> void:
	var player_data := inventory_service.player_data
	for index in range(player_data.potion_slot_count):
		if event.is_action_pressed("potion_slot_%d" % (index + 1)):
			player_data.select_potion_slot(index)
			hotbar.close_detail()
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			return
	if event.is_action_pressed("potion_next_slot"):
		player_data.select_potion_slot(posmod(player_data.selected_potion_slot + 1, player_data.potion_slot_count))
		hotbar.close_detail()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
	elif event.is_action_pressed("potion_previous_slot"):
		player_data.select_potion_slot(posmod(player_data.selected_potion_slot - 1, player_data.potion_slot_count))
		hotbar.close_detail()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func _connect_player_data() -> void:
	if inventory_service != null:
		return
	var current: Node = self
	while current != null and not current.has_method("get_player_data"):
		current = current.get_parent()
	if current == null:
		return
	var shared_player_data: PlayerData = current.call("get_player_data")
	if shared_player_data == null:
		return
	inventory_service = PotionInventoryService.new(shared_player_data)
	inventory_service.setup(shared_player_data)
	hotbar.setup(inventory_service, _definition_by_id, throw_tuning.dose_per_throw)


func _on_projectile_broken(_point: Vector2, _normal: Vector2) -> void:
	_active_projectile = null
	camera_director.stop_follow()
	if not _aiming:
		_restore_time()


func _on_projectile_exiting(projectile: PotionProjectile) -> void:
	if _active_projectile == projectile:
		_active_projectile = null
		camera_director.stop_follow()
		if not _aiming:
			_restore_time()


func _restore_time() -> void:
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	_restore_time()


func _abort_cast() -> void:
	_casting = false
	if _reservation != null:
		inventory_service.cancel_reservation(_reservation)
		_reservation = null
	magic_circle.hide_circle()
	_restore_time()


func _should_block_for_console(event: InputEvent) -> bool:
	var console := get_tree().root.find_child("DeveloperConsole", true, false)
	return console != null and console.has_method("is_open") and bool(console.call("is_open")) and event is InputEventKey


func _show_throw_tutorial_once() -> void:
	if tutorial_hint_id.is_empty():
		return
	var top_hint := get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	if top_hint != null:
		top_hint.push_hint(tutorial_hint_id)


func _init_definitions() -> void:
	_definition_by_id.clear()
	var defs := potion_definitions if not potion_definitions.is_empty() else default_definitions
	for definition in defs:
		if definition != null and definition.id != &"":
			_definition_by_id[definition.id] = definition
	if not _definition_by_id.is_empty():
		return
	var paths := [
		"res://shared/definitions/data/potions/red_potion.tres",
		"res://shared/definitions/data/potions/orange_potion.tres",
		"res://shared/definitions/data/potions/yellow_potion.tres",
		"res://shared/definitions/data/potions/green_potion.tres",
		"res://shared/definitions/data/potions/cyan_potion.tres",
		"res://shared/definitions/data/potions/blue_potion.tres",
		"res://shared/definitions/data/potions/purple_potion.tres",
		"res://shared/definitions/data/potions/purification_potion.tres",
		"res://shared/definitions/data/potions/black_potion.tres",
	]
	for path in paths:
		if ResourceLoader.exists(path):
			var resource := load(path) as PotionData
			if resource != null:
				_definition_by_id[resource.id] = resource
