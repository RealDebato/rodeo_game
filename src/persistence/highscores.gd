extends Node
## Autoload "Highscores": local highscore list, stored in user://highscores.cfg.
##
## Results are submitted when a game is completed (completion rule: Milestone 4).

signal changed

const FILE_PATH: String = "user://highscores.cfg"

var table := HighscoreTable.new()


func _ready() -> void:
	var file := ConfigFile.new()
	if file.load(FILE_PATH) == OK:
		var data: Variant = file.get_value("highscores", "entries", [])
		if data is Array:
			table.from_array(data)


## Fastest results first.
func entries() -> Array[Dictionary]:
	return table.entries


## Records a completed game. Returns the 0-based rank, or -1 if it did not make the list.
func submit(time_s: float, debris_id: String, initial_speed_deg_s: float) -> int:
	var rank := table.add(time_s, debris_id, initial_speed_deg_s, int(Time.get_unix_time_from_system()))
	if rank >= 0:
		var file := ConfigFile.new()
		file.set_value("highscores", "entries", table.to_array())
		var error := file.save(FILE_PATH)
		if error != OK:
			push_error("Highscores: could not save %s (error %d)" % [FILE_PATH, error])
		changed.emit()
	return rank
