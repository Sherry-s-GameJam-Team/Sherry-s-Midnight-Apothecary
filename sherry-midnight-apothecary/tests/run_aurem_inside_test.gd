extends SceneTree

const AUREM_LEVEL_TEST := preload("res://tests/aurem_clockyard_level_test.gd")
const AUREM_INSIDE_TEST := preload("res://tests/aurem_clockyard_inside_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	print("Running Aurem Clockyard Level Test...")
	AUREM_LEVEL_TEST.run(test)
	print("Running Aurem Clockyard Inside Test...")
	AUREM_INSIDE_TEST.run(test)

	if test.failures == 0:
		print("ALL AUREM CLOCKYARD TESTS PASSED!")
		quit(0)
	else:
		push_error("%d test assertion(s) failed." % test.failures)
		quit(1)
