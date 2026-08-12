extends SceneTree

const TEST_SCRIPTS: Array[Script] = [
	preload("res://tests/project_parse_test.gd"),
	preload("res://tests/menu_system_test.gd"),
	preload("res://tests/app_root_menu_test.gd"),
	preload("res://tests/game_flow_test.gd"),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	for test_script: Script in TEST_SCRIPTS:
		print("Running menu test suite: %s" % test_script.resource_path)
		test_script.run(test)
	if test.failures == 0:
		print("All menu integration tests passed (%d suites)." % TEST_SCRIPTS.size())
		quit(0)
	else:
		push_error("%d menu test assertion(s) failed." % test.failures)
		quit(1)
