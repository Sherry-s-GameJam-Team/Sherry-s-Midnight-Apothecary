extends SceneTree

const TEST_SUPPORT := preload("res://tests/test_support.gd")
const TEST_SUITES: Array[Script] = [
	preload("res://tests/aurem_clockyard_level_test.gd"),
	preload("res://tests/aurem_vespervale_transition_test.gd"),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	for suite: Script in TEST_SUITES:
		suite.run(test)
	if test.failures == 0:
		print("All Aurem Clockyard tests passed!")
		quit(0)
	else:
		push_error("%d test assertion(s) failed." % test.failures)
		quit(1)
