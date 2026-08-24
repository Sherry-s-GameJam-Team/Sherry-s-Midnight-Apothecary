extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test := TestSupport.new()
	preload("res://tests/business_shop_test.gd").run(test)
	if test.failures == 0:
		print("Business shop progression tests passed.")
		quit(0)
	else:
		push_error("%d business shop test assertion(s) failed." % test.failures)
		quit(1)

