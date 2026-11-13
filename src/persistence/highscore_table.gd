class_name HighscoreTable
extends RefCounted
## Sorted list of the best completion times (pure logic, no file access – see Highscores).
##
## Entry keys: "time_s" (float), "date_unix" (int), "debris_id" (String),
## "initial_speed_deg_s" (float). Fastest time first.

const MAX_ENTRIES: int = 10

var entries: Array[Dictionary] = []


## True if a result with this completion time would enter the table.
func qualifies(time_s: float) -> bool:
	return entries.size() < MAX_ENTRIES or time_s < float(entries[-1]["time_s"])


## Inserts a result. Returns its 0-based rank, or -1 if it did not qualify.
func add(time_s: float, debris_id: String, initial_speed_deg_s: float, date_unix: int) -> int:
	if not qualifies(time_s):
		return -1
	var entry := {
		"time_s": time_s,
		"date_unix": date_unix,
		"debris_id": debris_id,
		"initial_speed_deg_s": initial_speed_deg_s,
	}
	var rank := entries.size()
	for i: int in range(entries.size()):
		if time_s < float(entries[i]["time_s"]):
			rank = i
			break
	entries.insert(rank, entry)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	return rank


func to_array() -> Array:
	return entries.duplicate(true)


func from_array(data: Array) -> void:
	entries.clear()
	for item: Variant in data:
		if item is Dictionary and (item as Dictionary).has("time_s"):
			entries.append(item)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time_s"]) < float(b["time_s"]))
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
