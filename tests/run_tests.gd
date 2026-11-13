extends SceneTree
## Headless unit-test runner without third-party dependencies.
##
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Runs every method named test_* of every res://tests/test_*.gd script (each extends TestCase).
## Exit code = number of failed tests (0 = all passed).

const TEST_DIR: String = "res://tests/"


func _initialize() -> void:
	var total := 0
	var failed := 0
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script := load(TEST_DIR + file) as GDScript
		var test := script.new() as TestCase
		if test == null:
			push_error("%s does not extend TestCase" % file)
			failed += 1
			continue
		for method: Dictionary in test.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			test.current_test = "%s::%s" % [file.get_basename(), method_name]
			var failures_before := test.failures.size()
			test.call(method_name)
			if test.failures.size() > failures_before:
				failed += 1
				for i: int in range(failures_before, test.failures.size()):
					print("FAIL  ", test.failures[i])
			else:
				print("ok    ", test.current_test)
	print("\n%d tests, %d passed, %d failed" % [total, total - failed, failed])
	quit(failed)
