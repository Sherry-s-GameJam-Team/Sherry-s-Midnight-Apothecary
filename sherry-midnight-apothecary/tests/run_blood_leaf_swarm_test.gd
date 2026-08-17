extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_script: GDScript = load("res://tests/blood_leaf_swarm_test.gd")
	var test: RefCounted = test_script.new()
	test.call("run", root)
	quit(0)
