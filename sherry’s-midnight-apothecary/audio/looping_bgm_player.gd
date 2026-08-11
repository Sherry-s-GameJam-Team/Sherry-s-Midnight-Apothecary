extends AudioStreamPlayer

## Enforces sample-accurate looping even when the WAV importer drops loop metadata.

@export var loop_end_sample: int = -1


func _ready() -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		push_warning("LoopingBGMPlayer requires an AudioStreamWAV stream.")
		return

	var looping_wav := wav.duplicate() as AudioStreamWAV
	looping_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looping_wav.loop_begin = 0
	var full_length_samples := int(round(looping_wav.get_length() * looping_wav.mix_rate))
	looping_wav.loop_end = (
		clampi(loop_end_sample, 1, full_length_samples)
		if loop_end_sample > 0
		else full_length_samples
	)
	stream = looping_wav
	play()
