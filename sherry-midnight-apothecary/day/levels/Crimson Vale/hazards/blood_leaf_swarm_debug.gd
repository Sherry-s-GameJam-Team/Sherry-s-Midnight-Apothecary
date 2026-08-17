class_name BloodLeafSwarmDebug
extends Node2D

@export var swarm_scene: PackedScene = preload("res://day/levels/Crimson Vale/hazards/blood_leaf_swarm.tscn")
@export var active_swarm: BloodLeafSwarm
@export var debug_target: Node2D

var _last_spawned_swarm: BloodLeafSwarm


func _ready() -> void:
	if active_swarm != null:
		_bind_swarm(active_swarm)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return

	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_KP_1, KEY_1:
			_test_wind()
		KEY_KP_2, KEY_2:
			_test_explosion()
		KEY_KP_3, KEY_3:
			_test_purification()
		KEY_KP_4, KEY_4:
			_test_respawn()


func _test_wind() -> void:
	var target_swarm := _get_target_swarm()
	if target_swarm != null:
		var dir := Vector2.RIGHT.rotated(randf_range(-0.5, 0.5))
		target_swarm.hit_by_wind(dir, 480.0, 0.8)


func _test_explosion() -> void:
	var target_swarm := _get_target_swarm()
	if target_swarm != null:
		var explosion_pt := target_swarm.global_position + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		target_swarm.hit_by_explosion(explosion_pt, 1.2)


func _test_purification() -> void:
	var target_swarm := _get_target_swarm()
	if target_swarm != null:
		target_swarm.hit_by_purification(1.0)


func _test_respawn() -> void:
	if swarm_scene == null:
		return
	var inst := swarm_scene.instantiate() as BloodLeafSwarm
	if inst == null:
		return
	inst.global_position = global_position
	if debug_target != null:
		inst.target = debug_target
	get_parent().add_child(inst)
	_bind_swarm(inst)


func _bind_swarm(swarm: BloodLeafSwarm) -> void:
	_last_spawned_swarm = swarm
	if not swarm.purified.is_connected(_on_swarm_purified):
		swarm.purified.connect(_on_swarm_purified)


func _on_swarm_purified() -> void:
	_last_spawned_swarm = null


func _get_target_swarm() -> BloodLeafSwarm:
	if active_swarm != null and is_instance_valid(active_swarm):
		return active_swarm
	if _last_spawned_swarm != null and is_instance_valid(_last_spawned_swarm):
		return _last_spawned_swarm
	var swarms := get_tree().get_nodes_in_group("blood_leaf_swarm")
	for s: Node in swarms:
		if s is BloodLeafSwarm and is_instance_valid(s):
			return s as BloodLeafSwarm
	return null
