extends TestCase
## Highscore table: sorting, ranking, size limit, serialization.


func test_entries_are_sorted_fastest_first() -> void:
	var table := HighscoreTable.new()
	table.add(90.0, "envisat", 3.0, 1)
	table.add(45.0, "envisat", 2.5, 2)
	table.add(60.0, "envisat", 4.0, 3)
	var times: Array[float] = []
	for entry: Dictionary in table.entries:
		times.append(float(entry["time_s"]))
	assert_true(times == [45.0, 60.0, 90.0], str(times))


func test_rank_is_returned() -> void:
	var table := HighscoreTable.new()
	assert_true(table.add(50.0, "envisat", 3.0, 1) == 0)
	assert_true(table.add(40.0, "envisat", 3.0, 2) == 0)
	assert_true(table.add(70.0, "envisat", 3.0, 3) == 2)


func test_table_is_limited_and_slow_results_do_not_qualify() -> void:
	var table := HighscoreTable.new()
	for i: int in range(HighscoreTable.MAX_ENTRIES):
		table.add(10.0 + i, "envisat", 3.0, i)
	assert_true(not table.qualifies(100.0))
	assert_true(table.add(100.0, "envisat", 3.0, 99) == -1)
	assert_true(table.add(5.0, "envisat", 3.0, 99) == 0)
	assert_true(table.entries.size() == HighscoreTable.MAX_ENTRIES)
	assert_near(float(table.entries[-1]["time_s"]), 18.0, 1e-6, "slowest entry dropped")


func test_round_trip_through_array() -> void:
	var table := HighscoreTable.new()
	table.add(42.5, "envisat", 3.3, 1700000000)
	var copy := HighscoreTable.new()
	copy.from_array(table.to_array())
	assert_true(copy.entries.size() == 1)
	assert_near(float(copy.entries[0]["time_s"]), 42.5, 1e-6)
	assert_true(str(copy.entries[0]["debris_id"]) == "envisat")
