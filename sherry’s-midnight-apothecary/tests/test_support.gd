class_name TestSupport
extends RefCounted

var failures := 0


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("TEST FAILED: %s" % message)


func expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	expect(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])

