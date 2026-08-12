extends SceneTree

const TEST_SCRIPTS: Array[Script] = [
	preload("res://tests/project_parse_test.gd"),
	preload("res://tests/scene_title_system_test.gd"),
	preload("res://tests/menu_system_test.gd"),
	preload("res://tests/app_root_menu_test.gd"),
	preload("res://tests/animation_presentation_executor_test.gd"),
	preload("res://tests/bedroom_stick_interaction_test.gd"),
	preload("res://tests/home_day_one_intro_test.gd"),
	preload("res://tests/grassland_scene_test.gd"),
	preload("res://tests/sleeping_hound_tutorial_test.gd"),
	preload("res://tests/developer_console_test.gd"),
	preload("res://tests/player_data_test.gd"),
	preload("res://tests/potion_inventory_service_test.gd"),
	preload("res://tests/potion_hotbar_ui_test.gd"),
	preload("res://tests/game_flow_test.gd"),
	preload("res://tests/night_home_scene_test.gd"),
	preload("res://tests/save_service_test.gd"),
	preload("res://tests/alchemy_test.gd"),
	preload("res://tests/alchemy_background_pan_test.gd"),
	preload("res://tests/bellows_control_test.gd"),
	preload("res://tests/heat_controller_test.gd"),
	preload("res://tests/temperature_gauge_editor_test.gd"),
	preload("res://tests/production_test.gd"),
	preload("res://tests/pause_menu_test.gd"),
	preload("res://tests/pause_inventory_page_test.gd"),
	preload("res://tests/top_hint_ui_test.gd"),
	preload("res://tests/dialogue_integration_test.gd"),
	preload("res://tests/dual_world_structure_test.gd"),
	preload("res://tests/crimson_aqueduct_test.gd"),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	for test_script: Script in TEST_SCRIPTS:
		print("Running test suite: %s" % test_script.resource_path)
		test_script.run(test)
	if test.failures == 0:
		print("All simplified architecture tests passed (%d suites)." % TEST_SCRIPTS.size())
		quit(0)
	else:
		push_error("%d test assertion(s) failed." % test.failures)
		quit(1)
