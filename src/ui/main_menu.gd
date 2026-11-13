extends Node3D
## Main menu: 3D backdrop (procedural Earth, starfield, slowly tumbling Envisat) and the menu.
## START opens the game scene; HIGHSCORES / OPTIONS / CREDITS open panels over the backdrop.
## Android back: closes an open panel, otherwise quits.

const SATELLITE_SPIN_DEG_S: float = 6.0
const SATELLITE_SPIN_AXIS: Vector3 = Vector3(0.3, 1.0, 0.45)
const EARTH_SPIN_DEG_S: float = 1.5

var _open_panel: MenuPanel = null

@onready var _satellite: Node3D = $Satellite
@onready var _earth: Node3D = $Earth
@onready var _sun: DirectionalLight3D = $Sun
@onready var _camera: Camera3D = $Camera3D
@onready var _menu: Control = %MenuColumn
@onready var _start: Button = %StartButton
@onready var _highscores: Button = %HighscoresButton
@onready var _options: Button = %OptionsButton
@onready var _credits: Button = %CreditsButton
@onready var _quit: Button = %QuitButton
@onready var _options_panel: MenuPanel = %OptionsPanel
@onready var _highscores_panel: MenuPanel = %HighscoresPanel
@onready var _credits_panel: MenuPanel = %CreditsPanel


func _ready() -> void:
	_camera.look_at(Vector3(4.0, -2.0, 0.0))
	_sun.look_at_from_position(Vector3(40.0, 20.0, 30.0), Vector3.ZERO)
	_quit.visible = Platform.can_quit_app()
	_start.pressed.connect(_on_start_pressed)
	_highscores.pressed.connect(_show_panel.bind(_highscores_panel))
	_options.pressed.connect(_show_panel.bind(_options_panel))
	_credits.pressed.connect(_show_panel.bind(_credits_panel))
	_quit.pressed.connect(_quit_app)
	for panel: MenuPanel in [_options_panel, _highscores_panel, _credits_panel]:
		panel.hide()
		panel.closed.connect(_on_panel_closed)


func _process(delta: float) -> void:
	_satellite.rotate(SATELLITE_SPIN_AXIS.normalized(), deg_to_rad(SATELLITE_SPIN_DEG_S) * delta)
	_earth.rotate_y(deg_to_rad(EARTH_SPIN_DEG_S) * delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _open_panel != null:
			_open_panel.close()
		else:
			_quit_app()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _open_panel != null:
		_open_panel.close()


func _on_start_pressed() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.GAME)


func _show_panel(panel: MenuPanel) -> void:
	_open_panel = panel
	_menu.hide()
	panel.open()


func _on_panel_closed() -> void:
	_open_panel = null
	_menu.show()


func _quit_app() -> void:
	if Platform.can_quit_app():
		Settings.save_settings()
		get_tree().quit()
