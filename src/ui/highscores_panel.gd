extends MenuPanel
## Highscores screen: fastest de-tumbling times from the Highscores autoload.

const DEBRIS_NAMES: Dictionary = {"envisat": "Envisat"}

@onready var _list: VBoxContainer = %List
@onready var _empty: Label = %Empty
@onready var _back: Button = %BackButton


func _ready() -> void:
	_back.pressed.connect(close)


func _on_open() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	var entries := Highscores.entries()
	_empty.visible = entries.is_empty()
	for i: int in range(entries.size()):
		var entry := entries[i]
		var row := Label.new()
		row.text = "%2d.   %s     %s     start %.1f °/s     %s" % [
			i + 1,
			_format_time(float(entry.get("time_s", 0.0))),
			str(DEBRIS_NAMES.get(entry.get("debris_id", ""), entry.get("debris_id", "?"))),
			float(entry.get("initial_speed_deg_s", 0.0)),
			Time.get_date_string_from_unix_time(int(entry.get("date_unix", 0))),
		]
		_list.add_child(row)


static func _format_time(seconds: float) -> String:
	return "%d:%04.1f" % [floori(seconds / 60.0), fmod(seconds, 60.0)]
