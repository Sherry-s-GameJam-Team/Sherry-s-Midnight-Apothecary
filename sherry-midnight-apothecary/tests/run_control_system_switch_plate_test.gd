extends SceneTree

const SWITCH_PLATE_TEST := preload("res://tests/control_system_switch_plate_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	SWITCH_PLATE_TEST.run(test)
	if test.failures == 0:
		print("Control system switch & plate tests passed.")
		quit(0)
	else:
		push_error("%d control system assertion(s) failed." % test.failures)
		quit(1)
