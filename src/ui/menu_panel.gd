class_name MenuPanel
extends PanelContainer
## Base class of the screens opened from the main menu (options, highscores, credits).
## open() shows the panel; close() hides it and emits `closed` (BACK button, Android back).

signal closed


func open() -> void:
	_on_open()
	show()


func close() -> void:
	_on_close()
	hide()
	closed.emit()


## Override to refresh content before the panel is shown.
func _on_open() -> void:
	pass


## Override to persist changes before the panel hides.
func _on_close() -> void:
	pass
