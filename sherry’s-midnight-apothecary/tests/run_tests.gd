extends SceneTree

const TEST_SCRIPTS: Array[Script] = [
	preload("res://tests/project_parse_test.gd"),
	preload("res://tests/data_validation_test.gd"),
	preload("res://tests/game_session_test.gd"),
	preload("res://tests/game_flow_test.gd"),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	for test_script: Script in TEST_SCRIPTS:
		test_script.run(test)
	if test.failures == 0:
		print("All architecture tests passed (%d suites)." % TEST_SCRIPTS.size())
		quit(0)
	else:
		push_error("%d architecture test assertion(s) failed." % test.failures)
		quit(1)
