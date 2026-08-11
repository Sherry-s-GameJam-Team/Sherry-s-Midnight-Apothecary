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
		"res://day/ui/scene_title_card.tscn",
		"res://menu/menu.tscn",
		"res://menu/ui/menu_ui.tscn",
		"res://day/levels/market/town/town.tscn",
		"res://day/levels/home/home.tscn",
		"res://day/levels/home/bedroom.tscn",
		"res://day/systems/animation_presentation/animation_presentation_executor.tscn",
		"res://day/levels/grassland/grass.tscn",
		"res://day/art/raintree/raintree.tscn",
		"res://day/art/lake/lake.tscn",
		"res://night/night_runtime.tscn",
		"res://night/levels/home/home.tscn",
		"res://night/shop/business_placeholder.tscn",
		"res://night/alchemy/alchemy_runtime.tscn",
		"res://night/alchemy/brewing_panel.tscn",
		"res://night/alchemy/production/production_panel.tscn",
		"res://night/alchemy/production/powder_shelf_view.tscn",
		"res://night/ui/pause_menu/pause_menu.tscn",
		"res://night/ui/pause_menu/pause_inventory_page.tscn",
		"res://night/ui/top_hint/top_hint_ui.tscn",
		"res://shared/ui/task_complete/task_complete_ui.tscn",
		"res://tests/top_hint_ui_demo.tscn",
		"res://art/characters/sherry/sherry_test_scene.tscn",
		"res://art/characters/sherry/sherry_indoor_collision.tscn",
		"res://art/characters/sherry/sherry_outdoor_collision.tscn",
		"res://art/characters/luca/luca_player.tscn",
		"res://day/levels/_tests/dual_world/dual_world_puzzle_demo.tscn",
		"res://day/levels/_tests/dual_world/corrupted_alignment_preview.tscn",
		"res://day/levels/_tests/dual_world/original_alignment_preview.tscn",
		"res://tests/dual_world_runtime_test.tscn",
		"res://shared/potions/runtime/potion_player_system.tscn",
		"res://shared/potions/runtime/potion_projectile.tscn",
		"res://shared/potions/ui/potion_hotbar.tscn",
		"res://shared/potions/ui/potion_hotbar_slot.tscn",
		"res://shared/potions/ui/potion_order_panel.tscn",
	]:
		var scene := load(scene_path) as PackedScene
		test.expect(scene != null, "%s can be loaded." % scene_path)
		if scene != null:
			var instance := scene.instantiate()
			test.expect(instance != null, "%s can be instantiated." % scene_path)
			instance.free()
	for resource_path: String in [
		"res://art/effects/tree.png",
		"res://art/effects/bird.png",
		"res://menu/menu_silhouette_director.gd",
		"res://menu/shaders/menu_bird_trail.gdshader",
		"res://day/levels/grassland/grassland_level.tres",
	]:
		test.expect(load(resource_path) != null, "%s can be loaded." % resource_path)
