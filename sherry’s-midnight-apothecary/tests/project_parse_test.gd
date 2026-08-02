extends RefCounted


static func run(test: TestSupport) -> void:
	test.expect_equal(
		ProjectSettings.get_setting("application/run/main_scene"),
		"res://app/app_root.tscn",
		"AppRoot is the project main scene."
	)
	for scene_path: String in [
		"res://app/app_root.tscn",
		"res://night/ui/developer_console/developer_console.tscn",
		"res://day/day_runtime.tscn",
		"res://day/levels/market/town/town_environment.tscn",
		"res://day/levels/forest/raintree/raintree_environment.tscn",
		"res://day/levels/lake/lake_environment.tscn",
		"res://night/night_runtime.tscn",
		"res://night/alchemy/alchemy_runtime.tscn",
		"res://night/alchemy/brewing_panel.tscn",
		"res://night/alchemy/production/production_panel.tscn",
		"res://night/alchemy/production/powder_shelf_view.tscn",
		"res://night/ui/pause_menu/pause_menu.tscn",
		"res://art/characters/sherry/sherry_test_scene.tscn",
	]:
		var scene := load(scene_path) as PackedScene
		test.expect(scene != null, "%s can be loaded." % scene_path)
		if scene != null:
			var instance := scene.instantiate()
			test.expect(instance != null, "%s can be instantiated." % scene_path)
			instance.free()
