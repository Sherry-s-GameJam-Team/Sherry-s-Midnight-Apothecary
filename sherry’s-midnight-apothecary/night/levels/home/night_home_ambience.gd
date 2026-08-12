class_name NightHomeAmbience
extends AudioStreamPlayer

@export_node_path("Node2D") var listener_path := NodePath("../Player")
@export_node_path("Node2D") var barrier_path := NodePath("../BedroomBarrierVisual")
@export_range(-40.0, 0.0, 0.5) var room_volume_db := -8.0
@export_range(-50.0, -6.0, 0.5) var bedroom_volume_db := -30.0
@export_range(0.05, 2.0, 0.05) var smoothing_seconds := 0.45

var _listener: Node2D
var _barrier: Node2D


func _ready() -> void:
	_listener = get_node_or_null(listener_path) as Node2D
	_barrier = get_node_or_null(barrier_path) as Node2D
	if _listener == null or _barrier == null:
		push_error("NightHomeAmbience requires listener and bedroom barrier paths.")
		return
	var wav := stream as AudioStreamWAV
	if wav != null:
		var looping_wav := wav.duplicate() as AudioStreamWAV
		looping_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looping_wav.loop_begin = 0
		looping_wav.loop_end = int(round(looping_wav.get_length() * looping_wav.mix_rate))
		stream = looping_wav
	volume_db = _target_volume_db()
	play()


func _process(delta: float) -> void:
	if _listener == null or _barrier == null:
		return
	var weight := 1.0 - exp(-delta / maxf(smoothing_seconds, 0.01))
	volume_db = lerpf(volume_db, _target_volume_db(), weight)


func _target_volume_db() -> float:
	return bedroom_volume_db if _listener.global_position.x < _barrier.global_position.x else room_volume_db
