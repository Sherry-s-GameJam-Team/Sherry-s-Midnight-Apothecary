class_name DreamAudioSynth
extends Node

## Audio synthesizer for the Vespervale Inner Dream Hospital corridor.
## Produces distant bell chimes for telegraphs, dream transition whooshes, and crystal pulse tones.

const BELL_SAMPLE: AudioStream = preload("res://day/levels/Crimson Vale/sound/bell.wav")

var _players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_players()


func _ensure_players() -> void:
	if _players.is_empty():
		for i in range(10):
			var p := AudioStreamPlayer.new()
			p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
			add_child(p)
			_players.append(p)


func play_telegraph_chime(is_entering_dream: bool) -> void:
	if BELL_SAMPLE != null:
		var p := _get_idle_player()
		if p != null:
			p.stream = BELL_SAMPLE
			p.pitch_scale = 1.35 if is_entering_dream else 0.85
			p.volume_db = -4.0
			p.play()
	else:
		_play_synth_bell(660.0 if is_entering_dream else 440.0, 0.8)


func play_lock_bell() -> void:
	if BELL_SAMPLE != null:
		var p := _get_idle_player()
		if p != null:
			p.stream = BELL_SAMPLE
			p.pitch_scale = 0.55 # Deep, ominous low bell chime
			p.volume_db = -2.0
			p.play()
	else:
		_play_synth_bell(220.0, 1.0)


func play_shift_swoosh(is_dream: bool) -> void:
	var p := _get_idle_player()
	if p == null:
		return
	var sample_rate := 44100
	var duration := 0.45
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
		var freq := lerpf(240.0, 580.0, t) if is_dream else lerpf(520.0, 180.0, t)
		var val := sin(float(i) * (freq * TAU / sample_rate)) * 0.6 + (_rng.randf() * 0.3 - 0.15)
		var sample := int(clampf(val * env * 24000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, sample)
	stream.data = buffer
	p.stream = stream
	p.volume_db = -6.0
	p.play()


func play_crystal_pulse() -> void:
	var p := _get_idle_player()
	if p == null:
		return
	var sample_rate := 44100
	var duration := 0.8
	var total_frames := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var buffer := PackedByteArray()
	buffer.resize(total_frames * 2)
	for i in range(total_frames):
		var t := float(i) / float(total_frames)
		var env := exp(-t * 4.0)
		var f1 := 880.0
		var f2 := 1320.0
		var val := (sin(float(i) * (f1 * TAU / sample_rate)) * 0.5 + sin(float(i) * (f2 * TAU / sample_rate)) * 0.5)
		var sample := int(clampf(val * env * 28000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, sample)
	stream.data = buffer
	p.stream = stream
	p.volume_db = -3.0
	p.play()


func _play_synth_bell(base_freq: float, duration: float) -> void:
	var p := _get_idle_player()
	if p == null:
		return
	var sample_rate := 44100
	var total_frames := int(sample_rate * duration)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false

	var buffer := PackedByteArray()
	buffer.resize(total_frames * 2)
	for i in range(total_frames):
		var t := float(i) / float(total_frames)
		var env := exp(-t * 5.0)
		var val := sin(float(i) * (base_freq * TAU / sample_rate)) * 0.7 + sin(float(i) * (base_freq * 2.0 * TAU / sample_rate)) * 0.3
		var sample := int(clampf(val * env * 26000.0, -32768.0, 32767.0))
		buffer.encode_s16(i * 2, sample)
	stream.data = buffer
	p.stream = stream
	p.volume_db = -5.0
	p.play()


func _get_idle_player() -> AudioStreamPlayer:
	_ensure_players()
	for p: AudioStreamPlayer in _players:
		if is_instance_valid(p) and not p.playing:
			return p
	return _players[0] if not _players.is_empty() else null
