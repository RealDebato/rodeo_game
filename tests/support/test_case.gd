class_name TestCase
extends RefCounted
## Minimal assertion base class for headless unit tests (run by tests/run_tests.gd).
##
## Test scripts extend this class; every method named test_* is one test. Failed assertions are
## recorded (they do not abort the test), so one run reports all problems.

var failures: PackedStringArray = []
var current_test: String = ""


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("expected true. %s" % message)


func assert_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %s ± %s, got %s. %s" % [expected, tolerance, actual, message])


func assert_vec_near(actual: Vector3, expected: Vector3, tolerance: float, message: String = "") -> void:
	if actual.distance_to(expected) > tolerance:
		_fail("expected %s ± %s, got %s (distance %s). %s" % [
			expected, tolerance, actual, actual.distance_to(expected), message])


func _fail(message: String) -> void:
	failures.append("%s: %s" % [current_test, message])
