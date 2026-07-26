extends SceneTree

const LEVEL_SCENES := [
	"res://game/main/scenes/town/town_morning.tscn",
	"res://game/main/scenes/raintree/raintree.tscn",
	"res://game/main/scenes/lake/lake.tscn",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for scene_path in LEVEL_SCENES:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			failures.append("cannot load %s" % scene_path)
			continue
		var instance := packed.instantiate()
		if instance == null:
			failures.append("cannot instantiate %s" % scene_path)
			continue
		root.add_child(instance)
		if instance.get_node_or_null("LevelController") == null:
			failures.append("%s missing LevelController" % scene_path)
		if instance.get_node_or_null("PlayerSpawn") == null:
			failures.append("%s missing PlayerSpawn" % scene_path)
		if instance.get_node_or_null("CameraBounds") == null:
			failures.append("%s missing CameraBounds" % scene_path)
		if instance.get_node_or_null("Player") == null:
			failures.append("%s missing Player" % scene_path)
		instance.queue_free()

	var referenced_paths := _referenced_res_paths()
	for path in referenced_paths:
		if not FileAccess.file_exists(path):
			failures.append("missing external resource: %s" % path)

	if failures.is_empty():
		print("architecture_smoke_test: PASS")
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	quit(0)

func _referenced_res_paths() -> Array[String]:
	var paths: Array[String] = []
	for root_path in ["res://project.godot", "res://game"]:
		for file_path in _files_recursive(root_path):
			if not file_path.ends_with(".tscn") and not file_path.ends_with(".tres") and not file_path.ends_with(".gd"):
				continue
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file == null:
				continue
			var regex := RegEx.new()
			regex.compile("path=\\\"(res://[^\\\"]+)\\\"")
			for regex_match in regex.search_all(file.get_as_text()):
				var path: String = regex_match.get_string(1)
				if not paths.has(path):
					paths.append(path)
	return paths

func _files_recursive(path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return result
	for entry in dir.get_files():
		result.append(path.path_join(entry))
	for entry in dir.get_directories():
		result.append_array(_files_recursive(path.path_join(entry)))
	return result
