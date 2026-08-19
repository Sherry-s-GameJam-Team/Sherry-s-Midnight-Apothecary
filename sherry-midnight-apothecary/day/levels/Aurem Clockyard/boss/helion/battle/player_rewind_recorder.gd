class_name HelionRewindRecorder
extends Node

@export var record_buffer_seconds: float = 2.5

var player: Node2D
var is_recording: bool = false
var fallback_position: Vector2 = Vector2.ZERO

# Array of dictionaries: {"time": float, "position": Vector2, "velocity": Vector2}
var _snapshots: Array[Dictionary] = []

func _physics_process(_delta: float) -> void:
	if is_recording and is_instance_valid(player):
		var current_time = Time.get_ticks_msec() / 1000.0
		var snap = {
			"time": current_time,
			"position": player.global_position,
			"velocity": player.get("velocity") if "velocity" in player else Vector2.ZERO
		}
		_snapshots.append(snap)
		
		# Trim old entries
		var cutoff_time = current_time - record_buffer_seconds
		while _snapshots.size() > 0 and _snapshots[0].time < cutoff_time:
			_snapshots.pop_front()

func start_recording() -> void:
	is_recording = true
	_snapshots.clear()

func stop_recording() -> void:
	is_recording = false

func get_position_at(seconds_ago: float) -> Vector2:
	if _snapshots.is_empty():
		return fallback_position
		
	var target_time = (Time.get_ticks_msec() / 1000.0) - seconds_ago
	
	if _snapshots.size() == 1 or target_time <= _snapshots[0].time:
		return _snapshots[0].position
		
	if target_time >= _snapshots[-1].time:
		return _snapshots[-1].position
		
	for i in range(_snapshots.size() - 1):
		var s1 = _snapshots[i]
		var s2 = _snapshots[i+1]
		if s1.time <= target_time and target_time <= s2.time:
			var t = (target_time - s1.time) / (s2.time - s1.time)
			return s1.position.lerp(s2.position, t)
			
	return _snapshots[-1].position

func get_safe_rewind_position(seconds_ago: float, arena_rect: Rect2) -> Vector2:
	var check_time = seconds_ago
	var step = 0.1
	
	while check_time >= 0.0:
		var pos = get_position_at(check_time)
		if arena_rect.has_point(pos):
			return pos
		check_time -= step
		
	return fallback_position

func execute_rewind(seconds_ago: float, arena_rect: Rect2) -> Vector2:
	if not is_instance_valid(player):
		return fallback_position
		
	var safe_pos = get_safe_rewind_position(seconds_ago, arena_rect)
	player.global_position = safe_pos
	
	if "velocity" in player:
		player.velocity = Vector2.ZERO
		
	return safe_pos
