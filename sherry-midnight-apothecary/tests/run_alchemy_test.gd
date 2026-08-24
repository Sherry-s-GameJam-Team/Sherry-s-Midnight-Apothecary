extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	preload("res://tests/alchemy_test.gd").run(test)
	if test.failures == 0:
		print("Alchemy integration tests passed.")
		quit(0)
	else:
		push_error("%d alchemy test assertion(s) failed." % test.failures)
		quit(1)
