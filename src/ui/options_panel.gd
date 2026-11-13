extends MenuPanel
## Options screen: aiming method, sensitivity, invert, sensor calibration, laser power, graphics.
## Edits the Settings autoload; values are saved when the panel closes (and on calibration).
## Sound and music volume are added together with the audio system.

@onready var _aim_method: OptionButton = %AimMethod
@onready var _sensitivity: HSlider = %Sensitivity
@onready var _sensitivity_value: Label = %SensitivityValue
@onready var _invert: CheckButton = %InvertVertical
@onready var _calibrate: Button = %CalibrateButton
@onready var _laser_power: HSlider = %LaserPower
@onready var _laser_power_value: Label = %LaserPowerValue
@onready var _graphics: OptionButton = %Graphics
@onready var _status: Label = %Status
@onready var _back: Button = %BackButton


func _ready() -> void:
	_aim_method.clear()
	_aim_method.add_item("Virtual joystick", Settings.AIM_JOYSTICK)
	_aim_method.add_item("Motion sensors (tilt)", Settings.AIM_MOTION)
	_graphics.clear()
	_graphics.add_item("Low", Settings.GRAPHICS_LOW)
	_graphics.add_item("Medium", Settings.GRAPHICS_MEDIUM)
	_graphics.add_item("High", Settings.GRAPHICS_HIGH)
	_sensitivity.min_value = Settings.SENSITIVITY_MIN
	_sensitivity.max_value = Settings.SENSITIVITY_MAX
	_sensitivity.step = 0.05
	_laser_power.min_value = Settings.LASER_POWER_SCALE_MIN
	_laser_power.max_value = Settings.LASER_POWER_SCALE_MAX
	_laser_power.step = 0.05

	_aim_method.item_selected.connect(_on_aim_method_selected)
	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	_invert.toggled.connect(_on_invert_toggled)
	_calibrate.pressed.connect(_on_calibrate_pressed)
	_laser_power.value_changed.connect(_on_laser_power_changed)
	_graphics.item_selected.connect(_on_graphics_selected)
	_back.pressed.connect(close)


func _on_open() -> void:
	_aim_method.select(_aim_method.get_item_index(Settings.aim_method))
	_sensitivity.set_value_no_signal(Settings.aim_sensitivity)
	_invert.set_pressed_no_signal(Settings.invert_vertical)
	_laser_power.set_value_no_signal(Settings.laser_power_scale)
	_graphics.select(_graphics.get_item_index(Settings.graphics_quality))
	_update_value_labels()
	_status.text = _calibration_hint()


func _on_close() -> void:
	Settings.save_settings()


func _on_aim_method_selected(index: int) -> void:
	Settings.aim_method = _aim_method.get_item_id(index)
	_status.text = _calibration_hint()


func _on_sensitivity_changed(value: float) -> void:
	Settings.aim_sensitivity = value
	_update_value_labels()


func _on_invert_toggled(enabled: bool) -> void:
	Settings.invert_vertical = enabled


func _on_laser_power_changed(value: float) -> void:
	Settings.laser_power_scale = value
	_update_value_labels()


func _on_graphics_selected(index: int) -> void:
	Settings.graphics_quality = _graphics.get_item_id(index)
	Settings.apply_graphics()


func _on_calibrate_pressed() -> void:
	var gravity := Input.get_gravity()
	if gravity.length_squared() < MotionAimInput.MIN_GRAVITY_SQUARED:
		gravity = Input.get_accelerometer()
	if gravity.length_squared() < MotionAimInput.MIN_GRAVITY_SQUARED:
		_status.text = "No motion sensor data on this device."
		return
	Settings.calibrate_motion(gravity)
	_status.text = "Neutral position saved. Tilting from here moves the laser."


func _update_value_labels() -> void:
	_sensitivity_value.text = "%.2f" % _sensitivity.value
	_laser_power_value.text = "%d %%" % roundi(_laser_power.value * 100.0)


func _calibration_hint() -> String:
	if Settings.aim_method != Settings.AIM_MOTION:
		return "Joystick: drag on the left half of the screen to move the laser."
	if Settings.motion_calibrated:
		return "Tilt aiming is calibrated. Hold the phone as usual and tap CALIBRATE to change it."
	return "Hold the phone in your comfortable playing position and tap CALIBRATE."
