class_name AlkeonAudioSynth
extends Node

## Audio synthesizer & player for Alkeon boss battle
## Uses the authentic bronze bell sample (bell.wav) for wind chime tolls, dual warning dings,
## false chimes, and deep clock tower resonance, plus mechanical clock ticking.

const BELL_SAMPLE: AudioStream = preload("res://day/levels/Crimson Vale/sound/bell.wav")

var _audio_players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		add_child(p)
		_audio_players.append(p)


func play_chime_select(zone_index: int) -> void:
	# "当——" first ding: zone selected (Pitch: L=0.88, C=1.0, R=1.18)
	var pitches := [0.88, 1.0, 1.18]
	var pitch: float = pitches[clampi(zone_index, 0, 2)]
	_play_bell_sample(pitch, 0.9)


func play_chime_urgent(zone_index: int) -> void:
	# "当、当。" second urgent ding: attack imminent
	var pitches := [0.88, 1.0, 1.18]
	var pitch: float = pitches[clampi(zone_index, 0, 2)]
	_play_bell_sample(pitch, 1.0)
	get_tree().create_timer(0.18).timeout.connect(func() -> void:
		_play_bell_sample(pitch * 1.06, 1.1)
	)


func play_false_bell() -> void:
	# Muffled/detuned chime from Boss horns
	_play_bell_sample(0.72, 0.6)


func play_grand_clock_toll() -> void:
	# Deep resonant bronze clocktower bell
	_play_bell_sample(0.5, 1.2)
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		_play_bell_sample(0.62, 0.8)
	)


func play_clock_tick(fast: bool = false) -> void:
	# Precise mechanical clock tick
	var p := _get_idle_player()
	if p == null:
		return
	var sample_rate := 44100
	var duration := 0.04
	var total_frames := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(total_frames * 2)

	var freq := 1800.0 if not fast else 2200.0
	for i in range(total_frames):
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 80.0)
		var sample := sin(2.0 * PI * freq * t) * env * 0.4
		var int_val := clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, int_val)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	p.stream = stream
	p.pitch_scale = 1.0
	p.volume_db = -4.0
	p.play()


func _play_bell_sample(pitch: float, volume_linear: float) -> void:
	var p := _get_idle_player()
	if p == null:
		return
	p.stream = BELL_SAMPLE
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(clampf(volume_linear, 0.1, 1.5))
	p.play()


func _get_idle_player() -> AudioStreamPlayer:
	for p in _audio_players:
		if not p.playing:
			return p
	return _audio_players[0] if not _audio_players.is_empty() else null
