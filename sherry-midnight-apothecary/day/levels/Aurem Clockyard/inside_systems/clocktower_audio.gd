class_name ClocktowerAudio
extends Node

## Audio synthesizer and manager for the Aurem Clocktower ascent.
## Provides mechanical ticks, steam releases, bell chimes, spring pulses, and grand synchronization tolls.

const BELL_SAMPLE: AudioStream = preload("res://day/levels/Crimson Vale/sound/bell.wav")

var _players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in range(12):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		add_child(p)
		_players.append(p)


func play_tick(pitch: float = 1.0, volume_db: float = -6.0) -> void:
	var p := _get_idle_player()
	if p == null:
		return
	var sample_rate := 44100
	var duration := 0.03
	var total_frames := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(sample_rate * pitch)
	stream.stereo = false

	var buffer := PackedByteArray()
	buffer.resize(total_frames * 2)
	for i in range(total_frames):
		var t := float(i) / float(total_frames)
		var env := (1.0 - t) * (1.0 - t)
		var val := sin(float(i) * 0.45) * 0.7 + (_rng.randf() * 2.0 - 1.0) * 0.3
		var sample := int(clampf(val * env * 30000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, sample)
	stream.data = buffer
	p.stream = stream
	p.volume_db = volume_db
	p.play()


func play_bell_warning(urgent: bool = false) -> void:
	if urgent:
		_play_bell(1.2, -2.0)
		var timer := get_tree().create_timer(0.16)
		timer.timeout.connect(func() -> void:
			_play_bell(1.3, -1.0)
		)
	else:
		_play_bell(1.0, -3.0)


func play_spring_pulse() -> void:
	var p := _get_idle_player()
	if p == null:
		return
	var sample_rate := 44100
	var duration := 0.5
	var total_frames := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var buffer := PackedByteArray()
	buffer.resize(total_frames * 2)
	for i in range(total_frames):
		var t := float(i) / float(total_frames)
		var env := exp(-t * 6.0)
		var freq := lerpf(120.0, 45.0, t)
		var val := sin(float(i) * (freq * TAU / sample_rate)) * 0.8 + (_rng.randf() * 0.4 - 0.2)
		var sample := int(clampf(val * env * 32000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, sample)
	stream.data = buffer
	p.stream = stream
	p.volume_db = 0.0
	p.play()


func play_gear_clack() -> void:
	var p := _get_idle_player()
	if p == null:
		return
	var sample_rate := 44100
	var duration := 0.08
	var total_frames := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var buffer := PackedByteArray()
	buffer.resize(total_frames * 2)
	for i in range(total_frames):
		var t := float(i) / float(total_frames)
		var env := (1.0 - t) * (1.0 - t)
		var val := sin(float(i) * 0.8) * 0.5 + (_rng.randf() * 2.0 - 1.0) * 0.5
		var sample := int(clampf(val * env * 28000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, sample)
	stream.data = buffer
	p.stream = stream
	p.volume_db = -4.0
	p.play()


func play_gear_grind_warning() -> void:
	var p := _get_idle_player()
	if p == null:
		return
	var sample_rate := 44100
	var duration := 0.6
	var total_frames := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var buffer := PackedByteArray()
	buffer.resize(total_frames * 2)
	for i in range(total_frames):
		var t := float(i) / float(total_frames)
		var env := sin(t * PI)
		var val := sin(float(i) * 0.35) * sin(float(i) * 0.04) * 0.7 + (_rng.randf() * 0.6 - 0.3)
		var sample := int(clampf(val * env * 26000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, sample)
	stream.data = buffer
	p.stream = stream
	p.volume_db = -2.0
	p.play()


func play_grand_synchronization_toll() -> void:
	# Deep resonant bronze clocktower bell
	_play_bell(0.48, 4.0)
	var timer1 := get_tree().create_timer(0.08)
	timer1.timeout.connect(func() -> void:
		_play_bell(0.60, 2.0)
	)
	var timer2 := get_tree().create_timer(0.25)
	timer2.timeout.connect(func() -> void:
		_play_bell(0.96, 0.0)
	)


func play_calibration_fixed() -> void:
	_play_bell(1.4, -2.0)
	play_gear_clack()


func _play_bell(pitch: float, volume_db: float) -> void:
	var p := _get_idle_player()
	if p == null:
		return
	p.stream = BELL_SAMPLE
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _get_idle_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0] if _players.size() > 0 else null
