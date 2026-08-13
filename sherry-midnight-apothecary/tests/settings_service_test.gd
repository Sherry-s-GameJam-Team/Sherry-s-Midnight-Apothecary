extends RefCounted


static func run(test: TestSupport) -> void:
	var path := "user://settings_service_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var tree := Engine.get_main_loop() as SceneTree
	var service := preload("res://app/settings_service.gd").new(path)
	tree.root.add_child(service)
	service.load_and_apply()
	test.expect_equal(service.get_value(&"text_size"), 1, "Settings default to standard text size.")
	service.set_value(&"music_volume", 0.37)
	service.set_value(&"resolution", [1600, 900])
	service.set_value(&"dialogue_speed", 2)
	service.flush()
	test.expect(FileAccess.file_exists(path), "Settings persist independently to their own file.")
	var loaded := preload("res://app/settings_service.gd").new(path)
	tree.root.add_child(loaded)
	loaded.load_and_apply()
	test.expect_float_close(float(loaded.get_value(&"music_volume")), 0.37, 0.001, "Saved music volume reloads.")
	test.expect_equal(loaded.get_value(&"resolution"), [1600, 900], "Saved window resolution reloads.")
	var music_bus := AudioServer.get_bus_index("Music")
	var ui_bus := AudioServer.get_bus_index("UI")
	test.expect(music_bus >= 0 and ui_bus >= 0, "Settings create stable Music and UI buses.")
	test.expect_float_close(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), 0.37, 0.01, "Music volume changes only the Music bus.")
	loaded.set_value(&"music_volume", 0.0)
	test.expect(AudioServer.is_bus_mute(music_bus), "Zero percent cleanly mutes a category bus.")
	loaded.reset_defaults()
	test.expect(not AudioServer.is_bus_mute(music_bus), "Reset defaults restores category audio.")
	loaded.free()
	service.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
