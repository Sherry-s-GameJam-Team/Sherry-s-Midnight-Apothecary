class_name FireStateLibrary
extends Resource

## The supplied art package is intentionally data-driven: every heat state has
## the same number of complete RGBA furnace frames, listed in its manifest.
@export_file("*.json") var manifest_path := "res://game/apothecary/fire_visual/assets/microstates/state_manifest.json"
@export_dir var asset_root := "res://game/apothecary/fire_visual/assets/microstates"

var _manifest: Dictionary = {}
var _states: Array[Dictionary] = []
var _frame_cache: Dictionary[int, SpriteFrames] = {}


func load_states() -> void:
	if not _states.is_empty():
		return

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		push_error("FireStateLibrary cannot read manifest: %s" % manifest_path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("FireStateLibrary manifest is not a JSON object: %s" % manifest_path)
		return
	_manifest = parsed as Dictionary

	for state_data: Dictionary in _manifest.get("states", []):
		_states.append(state_data)


func state_count() -> int:
	load_states()
	return _states.size()


func state(index: int) -> Dictionary:
	load_states()
	if _states.is_empty():
		return {}
	var clamped_index := clampi(index, 0, _states.size() - 1)
	var state_data := _states[clamped_index]
	var frames := _frame_cache.get(clamped_index) as SpriteFrames
	if frames == null:
		frames = _make_frames(state_data)
		if frames.get_frame_count(&"loop") == 0:
			push_error("FireStateLibrary state %s contains no usable frames." % state_data.get("id", "?"))
			return {}
		_frame_cache[clamped_index] = frames
	return {
		"fire": frames,
		"frame_count": frames.get_frame_count(&"loop"),
		"playback_speed": float(state_data.get("fps", _manifest.get("microstate_fps", 15.0))),
	}


## Only the two states currently blended by the controller need to remain in RAM.
func retain_states(indices: Array[int]) -> void:
	var retained: Dictionary[int, bool] = {}
	for index: int in indices:
		retained[index] = true
	for cached_index: int in _frame_cache.keys():
		if not retained.has(cached_index):
			_frame_cache.erase(cached_index)


func _make_frames(state_data: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(&"loop")
	frames.set_animation_loop(&"loop", true)
	frames.set_animation_speed(&"loop", float(state_data.get("fps", _manifest.get("microstate_fps", 15.0))))

	var relative_paths: Array = state_data.get("frames", [])
	if relative_paths.is_empty():
		var state_id := int(state_data.get("id", 0))
		var frame_count := int(state_data.get("frame_count", _manifest.get("microstate_frame_count", 12)))
		for frame_index: int in frame_count:
			relative_paths.append("states/s%02d/fire_s%02d_%03d.png" % [state_id, state_id, frame_index])

	for relative_path_variant: Variant in relative_paths:
		var relative_path := str(relative_path_variant)
		var texture := load(asset_root.path_join(relative_path)) as Texture2D
		if texture == null:
			push_error("FireStateLibrary cannot load fire frame: %s" % asset_root.path_join(relative_path))
			continue
		frames.add_frame(&"loop", texture)
	return frames
