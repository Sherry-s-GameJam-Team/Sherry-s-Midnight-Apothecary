extends SceneTree

const TestScript := preload("res://tests/alkeon_boss_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var tester := TestScript.new()
	tester.run(root)
	quit(0)
