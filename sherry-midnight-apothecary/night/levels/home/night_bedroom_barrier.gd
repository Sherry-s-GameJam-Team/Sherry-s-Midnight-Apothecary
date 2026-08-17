class_name NightBedroomBarrier
extends Node

signal check_started
signal check_finished
signal business_ended
signal barrier_opened

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export_node_path("HomeCameraDirector") var camera_director_path: NodePath
@export var dialogue_resource: DialogueResource = preload("res://night/levels/home/night_bedroom_barrier.dialogue")

var has_operated := false
var remaining_customers := 0
var completed_customers := 0
var is_checking := false
var is_barrier_open := false

var _camera_director: HomeCameraDirector
var _modal_lock_was_set := false
var _balloon: Node


func _ready() -> void:
	# HomeCameraDirector is a sibling that has already entered the tree when this
	# node becomes ready. Bind immediately so the entrance never has a one-frame
	# window in which it bypasses the night barrier check.
	_setup_camera_director()


func _exit_tree() -> void:
	if is_instance_valid(_balloon):
		_balloon.queue_free()
	_balloon = null
	_release_modal_lock()


func _setup_camera_director() -> void:
	_camera_director = get_node_or_null(camera_director_path) as HomeCameraDirector
	if _camera_director == null:
		var parent := get_parent()
		if parent != null:
			_camera_director = parent.get_node_or_null("HomeCameraDirector") as HomeCameraDirector
	if _camera_director != null:
		_camera_director.entrance_handler = _on_barrier_interacted


func _on_barrier_interacted() -> void:
	if is_checking:
		return
	trigger_barrier_check()


func trigger_barrier_check(on_decision: Callable = Callable()) -> void:
	is_checking = true
	check_started.emit()
	_update_business_state()
	_acquire_modal_lock()
	if _camera_director != null:
		_camera_director.hide_entrance_hint()
	_open_dialogue(on_decision)


func confirm_end_business() -> void:
	is_barrier_open = true
	if _camera_director != null:
		_camera_director.open_barrier()
	business_ended.emit()
	barrier_opened.emit()


func _update_business_state() -> void:
	var home := _find_night_home()
	if home != null:
		has_operated = home.has_operated()
		remaining_customers = home.get_remaining_customer_count()
		completed_customers = home.get_completed_customer_count()
	else:
		has_operated = false
		remaining_customers = 0
		completed_customers = 0


func _open_dialogue(on_decision: Callable) -> void:
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null or dialogue_resource == null:
		_finish_check(on_decision)
		return
	_balloon = dialogue_manager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		dialogue_resource,
		"check_barrier",
		[self]
	)
	if _balloon == null:
		_finish_check(on_decision)
		return
	_balloon.tree_exited.connect(func() -> void:
		_balloon = null
		_finish_check(on_decision)
	, CONNECT_ONE_SHOT)


func _finish_check(on_decision: Callable) -> void:
	_release_modal_lock()
	is_checking = false
	check_finished.emit()
	if on_decision.is_valid():
		on_decision.call(is_barrier_open)


func _acquire_modal_lock() -> void:
	if get_tree() != null:
		_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
		get_tree().set_meta("day_modal_input_locked", true)


func _release_modal_lock() -> void:
	if get_tree() != null and not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")


func _find_night_home() -> NightHome:
	var current: Node = self
	while current != null:
		if current is NightHome:
			return current as NightHome
		current = current.get_parent()
	return null
