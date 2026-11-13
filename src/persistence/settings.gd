extends Node
## Autoload "Settings": persistent player options, stored in user://settings.cfg.
##
## Read the values anywhere as Settings.<property>. Systems read what they need when a game
## starts (aiming, laser power); engine-level options (graphics) are applied by apply_graphics().
## Changes are saved by save_settings(), and automatically when the app is paused or closed.

signal changed

const FILE_PATH: String = "user://settings.cfg"

const AIM_JOYSTICK: int = 0
const AIM_MOTION: int = 1

const GRAPHICS_LOW: int = 0
const GRAPHICS_MEDIUM: int = 1
const GRAPHICS_HIGH: int = 2

const SENSITIVITY_MIN: float = 0.2
const SENSITIVITY_MAX: float = 2.0
const LASER_POWER_SCALE_MIN: float = 0.5
const LASER_POWER_SCALE_MAX: float = 1.5

## Neutral phone pose for tilt aiming before the first calibration: landscape, tilted back ~35°.
## Godot's gravity vector is in screen axes (x right, y up, z out of the screen), pointing down.
const DEFAULT_NEUTRAL_GRAVITY: Vector3 = Vector3(0.0, -8.0, -5.6)

var aim_method: int = AIM_JOYSTICK
var aim_sensitivity: float = 1.0
var invert_vertical: bool = false
var motion_neutral_gravity: Vector3 = DEFAULT_NEUTRAL_GRAVITY
var motion_calibrated: bool = false
var laser_power_scale: float = 1.0
var graphics_quality: int = GRAPHICS_MEDIUM


func _ready() -> void:
	load_settings()
	apply_graphics()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(FILE_PATH) != OK:
		return
	aim_method = clampi(int(file.get_value("aim", "method", aim_method)), AIM_JOYSTICK, AIM_MOTION)
	aim_sensitivity = clampf(float(file.get_value("aim", "sensitivity", aim_sensitivity)), SENSITIVITY_MIN, SENSITIVITY_MAX)
	invert_vertical = bool(file.get_value("aim", "invert_vertical", invert_vertical))
	var neutral: Variant = file.get_value("aim", "motion_neutral_gravity", motion_neutral_gravity)
	if neutral is Vector3 and (neutral as Vector3).length_squared() > 0.01:
		motion_neutral_gravity = neutral
	motion_calibrated = bool(file.get_value("aim", "motion_calibrated", motion_calibrated))
	laser_power_scale = clampf(float(file.get_value("laser", "power_scale", laser_power_scale)), LASER_POWER_SCALE_MIN, LASER_POWER_SCALE_MAX)
	graphics_quality = clampi(int(file.get_value("graphics", "quality", graphics_quality)), GRAPHICS_LOW, GRAPHICS_HIGH)


func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("aim", "method", aim_method)
	file.set_value("aim", "sensitivity", aim_sensitivity)
	file.set_value("aim", "invert_vertical", invert_vertical)
	file.set_value("aim", "motion_neutral_gravity", motion_neutral_gravity)
	file.set_value("aim", "motion_calibrated", motion_calibrated)
	file.set_value("laser", "power_scale", laser_power_scale)
	file.set_value("graphics", "quality", graphics_quality)
	var error := file.save(FILE_PATH)
	if error != OK:
		push_error("Settings: could not save %s (error %d)" % [FILE_PATH, error])
	changed.emit()


## Stores the current phone pose (gravity vector, screen axes) as neutral tilt-aiming pose.
func calibrate_motion(gravity: Vector3) -> void:
	motion_neutral_gravity = gravity
	motion_calibrated = true
	save_settings()
	print("[Settings] motion neutral gravity = %s" % gravity)


## Applies the graphics quality to the root viewport (3D resolution scale and anti-aliasing).
func apply_graphics() -> void:
	var viewport := get_tree().root
	match graphics_quality:
		GRAPHICS_LOW:
			viewport.scaling_3d_scale = 0.7
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		GRAPHICS_MEDIUM:
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		_:
			viewport.scaling_3d_scale = 1.0
			viewport.msaa_3d = Viewport.MSAA_4X
