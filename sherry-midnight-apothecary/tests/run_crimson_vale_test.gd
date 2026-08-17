extends SceneTree

const TEST_SUPPORT := preload("res://tests/test_support.gd")
const TEST_SUITE := preload("res://tests/crimson_vale_level_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	print("Running test suite: res://tests/crimson_vale_level_test.gd")
	TEST_SUITE.run(test)
	if test.failures == 0:
		print("All Crimson Vale tests passed!")
		quit(0)
	else:
		push_error("%d test assertion(s) failed." % test.failures)
		quit(1)
