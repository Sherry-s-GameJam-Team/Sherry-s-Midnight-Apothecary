extends SceneTree

func _init() -> void:
	var test_support = preload("res://tests/test_support.gd").new()
	var helion_test = preload("res://tests/helion_boss_test.gd").new()

	helion_test.run(test_support)

	if test_support.failures > 0:
		push_error("%d test assertion(s) failed." % test_support.failures)
		quit(1)
	else:
		print("ALL HELION BOSS TESTS PASSED!")
		quit(0)