extends SceneTree


func _initialize() -> void:
	var test := TestSupport.new()
	preload("res://tests/potion_inventory_service_test.gd").run(test)
	if test.failures == 0:
		print("Potion inventory service tests passed.")
		quit(0)
	else:
		push_error("%d potion test assertion(s) failed." % test.failures)
		quit(1)
