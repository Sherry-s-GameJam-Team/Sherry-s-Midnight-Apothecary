extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	var test_script: Script = preload("res://tests/spectrum_codex_test.gd")
	print("Running spectrum codex test suite: %s" % test_script.resource_path)
	test_script.run(test)
	if test.failures == 0:
		print("All spectrum codex tests passed!")
		quit(0)
	else:
		push_error("%d test assertion(s) failed." % test.failures)
		quit(1)
