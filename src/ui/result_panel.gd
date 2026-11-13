class_name ResultPanel
extends PanelContainer
## Win screen: thank-you message, completion time and place in the highscore list.

signal restart_requested
signal menu_requested

@onready var _time: Label = %TimeValue
@onready var _place: Label = %PlaceValue
@onready var _restart: Button = %RestartButton
@onready var _menu: Button = %MenuButton


func _ready() -> void:
	_restart.pressed.connect(restart_requested.emit)
	_menu.pressed.connect(menu_requested.emit)


## `rank` is the 0-based place in the highscore list, or -1 if the time did not make the list.
func show_result(time_s: float, rank: int, entry_count: int, best_time_s: float) -> void:
	_time.text = TimeFormat.mission_time(time_s)
	if rank == 0:
		_place.text = "NEW RECORD  -  PLACE 1 OF %d" % entry_count
	elif rank > 0:
		_place.text = "PLACE %d OF %d IN THE HIGHSCORE LIST" % [rank + 1, entry_count]
	else:
		_place.text = "NOT IN THE TOP %d  -  BEST TIME %s" % [HighscoreTable.MAX_ENTRIES, TimeFormat.mission_time(best_time_s)]
	show()
