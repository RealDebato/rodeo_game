class_name PausePanel
extends PanelContainer
## Pause menu: RESUME / RESTART / MAIN MENU. Runs while the scene tree is paused
## (process_mode = ALWAYS). Esc resumes.

signal resume_requested
signal restart_requested
signal menu_requested

@onready var _resume: Button = %ResumeButton
@onready var _restart: Button = %RestartButton
@onready var _menu: Button = %MenuButton


func _ready() -> void:
	_resume.pressed.connect(resume_requested.emit)
	_restart.pressed.connect(restart_requested.emit)
	_menu.pressed.connect(menu_requested.emit)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
