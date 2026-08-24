extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	preload("res://tests/colored_plant_library_test.gd").run(test)
	if test.failures == 0:
		print("Colored plant library tests passed.")
		quit(0)
	else:
		push_error("%d colored plant test assertion(s) failed." % test.failures)
		quit(1)

