extends RefCounted

const DAY_SCENE := preload("res://day/day_runtime.tscn")


static func run(test: TestSupport) -> void:
	var level := LevelData.new()
	level.id = &"test_level"
	level.display_name = "Test Location"
	level.scene_description = "Ordinary scene description"
	level.disaster_name = "Named Disaster"
	level.disaster_days = [3, 8]
	test.expect(not level.is_disaster_day(2), "A normal day does not activate the disaster title.")
	test.expect(level.is_disaster_day(3), "A configured disaster day activates the disaster title.")
	test.expect_equal(level.title_subtitle_for_day(2), "Ordinary scene description", "Normal scenes use the scene description subtitle.")
	test.expect_equal(level.title_subtitle_for_day(8), "Named Disaster", "Disaster scenes use only the disaster name subtitle.")

	var day_one_key := DayRuntime.scene_title_seen_key(1, &"market")
	var day_two_key := DayRuntime.scene_title_seen_key(2, &"market")
	var forest_key := DayRuntime.scene_title_seen_key(1, &"forest")
	test.expect_equal(day_one_key, "scene_title_seen:1:market", "Title persistence keys include day and level ID.")
	test.expect(day_one_key != day_two_key, "The same scene can present again on a later day.")
	test.expect(day_one_key != forest_key, "Different scenes track title presentation independently.")

	var tree := Engine.get_main_loop() as SceneTree
	var player := PlayerData.new()
	var runtime := DAY_SCENE.instantiate() as DayRuntime
	runtime.player_data = player
	runtime.day = 1
	tree.root.add_child(runtime)
	test.expect(bool(player.tutorial_flags.get(day_one_key, false)), "Automatically presenting Town persists its seen marker.")
	test.expect(not runtime._play_scene_title_once(), "The same scene title is not automatically presented twice in one day.")
	test.expect(runtime.replay_scene_title(true), "Manual title replay ignores the persisted seen marker.")
	test.expect(runtime.switch_to_level("forest"), "The runtime can enter a second titled scene.")
	test.expect(bool(player.tutorial_flags.get(forest_key, false)), "A different scene receives its own daily seen marker.")
	test.expect(runtime.switch_to_level("home"), "The runtime can enter a title-disabled scene.")
	test.expect(not runtime.replay_scene_title(true), "Title-disabled scenes reject manual replay.")
	test.expect(not player.tutorial_flags.has(DayRuntime.scene_title_seen_key(1, &"home")), "Title-disabled scenes do not create seen markers.")
	runtime.free()

	var restored := PlayerData.from_save_data(player.to_save_data())
	test.expect(bool(restored.tutorial_flags.get(day_one_key, false)), "Scene title seen markers survive save-data round trips.")

	var runtime_scene_source := FileAccess.get_file_as_string("res://day/day_runtime.tscn")
	test.expect(not runtime_scene_source.contains("LevelTitle"), "DayRuntime no longer contains a persistent LevelTitle.")
	var embedded_title_count := 0
	for scene_path in _day_scene_paths():
		var source := FileAccess.get_file_as_string(scene_path)
		if source.contains("res://day/ui/scene_title_card.tscn"):
			embedded_title_count += 1
	test.expect_equal(embedded_title_count, 0, "Day level scenes do not embed their own SceneTitleCard.")


static func _day_scene_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	_collect_scene_paths("res://day/art", paths)
	_collect_scene_paths("res://day/levels", paths)
	return paths


static func _collect_scene_paths(directory_path: String, paths: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_collect_scene_paths(path, paths)
		elif entry.ends_with(".tscn"):
			paths.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
