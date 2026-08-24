extends SceneTree

const TestSupport = preload("res://tests/test_support.gd")
const DreamGraspTest = preload("res://tests/dream_grasp_hands_test.gd")
const VespervaleInnerTest = preload("res://tests/vespervale_inner_level_test.gd")

func _init() -> void:
	var test = TestSupport.new()
	print("--- Running Dream Grasp Hands Tests ---")
	DreamGraspTest.run(test)
	print("--- Running Vespervale Inner Level Tests ---")
	VespervaleInnerTest.run(test)
	print("--- ALL DREAM GRASP & VESPERVALE INNER TESTS PASSED! ---")
	quit(0)