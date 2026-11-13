class_name TimeFormat
extends RefCounted
## Formatting of mission times.


## "m:ss.s", e.g. 83.42 -> "1:23.4".
static func mission_time(seconds: float) -> String:
	var tenths := roundi(maxf(seconds, 0.0) * 10.0)
	var minutes := floori(tenths / 600.0)
	var rest_s := (tenths - minutes * 600) / 10.0
	return "%d:%04.1f" % [minutes, rest_s]
