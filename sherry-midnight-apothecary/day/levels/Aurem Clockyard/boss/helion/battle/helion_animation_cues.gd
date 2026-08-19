class_name HelionAnimationCues
extends Resource
## Animation-driven gameplay cue system.
##
## Each cue entry maps (animation_name, local_frame) → cue_id.
## Boss logic listens to AnimatedSprite2D.frame_changed, queries this
## resource, and dispatches matching cues.  Source frame numbers (0–179)
## are NEVER used at runtime — only animation_name + local_frame.

## Each element: { "animation": StringName, "local_frame": int, "cue_id": StringName }
@export var cues: Array[Dictionary] = []

# ─── Runtime lookup cache (built on first query) ───
var _cache: Dictionary = {}   # { StringName(anim) : { int(frame) : Array[StringName] } }
var _cache_dirty: bool = true


func _init() -> void:
	_cache_dirty = true


## Return all cue IDs that fire at the given animation + local frame.
func get_cues_at(animation_name: StringName, local_frame: int) -> Array[StringName]:
	if _cache_dirty:
		_rebuild_cache()
	var anim_dict: Dictionary = _cache.get(animation_name, {})
	var result: Variant = anim_dict.get(local_frame, null)
	if result == null:
		return [] as Array[StringName]
	return result as Array[StringName]


## Check whether a specific cue fires at the given animation + frame.
func has_cue(animation_name: StringName, local_frame: int, cue_id: StringName) -> bool:
	var ids := get_cues_at(animation_name, local_frame)
	return ids.has(cue_id)


## Force cache rebuild (call after editing cues at runtime).
func invalidate_cache() -> void:
	_cache_dirty = true


func _rebuild_cache() -> void:
	_cache.clear()
	for entry: Dictionary in cues:
		var anim: StringName = StringName(entry.get("animation", ""))
		var frame: int = int(entry.get("local_frame", -1))
		var cid: StringName = StringName(entry.get("cue_id", ""))
		if anim == &"" or frame < 0 or cid == &"":
			continue
		if not _cache.has(anim):
			_cache[anim] = {}
		var frame_dict: Dictionary = _cache[anim]
		if not frame_dict.has(frame):
			frame_dict[frame] = [] as Array[StringName]
		(frame_dict[frame] as Array[StringName]).append(cid)
	_cache_dirty = false
