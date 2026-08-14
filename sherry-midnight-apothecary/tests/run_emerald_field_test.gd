extends SceneTree

const EMERALD_FIELD_TEST := preload("res://tests/emerald_field_level_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	EMERALD_FIELD_TEST.run(test)
	if test.failures == 0:
		print("Emerald Field deployment tests passed.")
		quit(0)
	else:
		push_error("%d Emerald Field assertion(s) failed." % test.failures)
		quit(1)
