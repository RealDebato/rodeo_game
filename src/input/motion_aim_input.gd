class_name MotionAimInput
extends AimInput
## Tilt aiming with absolute control: the phone's tilt relative to a calibrated neutral pose
## sets the aim angles directly.
##   steering-wheel roll (right edge down)      -> aim right
##   tilting the top edge towards the player    -> aim up      (invert option flips this)
##
## Sensor: Godot's gravity vector (Android's fused gravity sensor = accelerometer + gyroscope
## where available), falling back to a low-pass-filtered accelerometer. Because the aim is
## referenced to gravity, it cannot drift (integrating the gyroscope alone would). A dead zone
## suppresses hand tremor and exponential smoothing removes sensor noise.
## Godot reports gravity in screen axes: x right, y up, z out of the screen.

const MIN_GRAVITY_SQUARED: float = 0.01

## Gravity vector of the neutral pose (Settings.motion_neutral_gravity).
var neutral_gravity: Vector3

var _gravity_source: Callable
var _filtered_accelerometer: Vector3 = Vector3.ZERO
var _last_gravity: Vector3 = Vector3.ZERO


## `gravity_source` () -> Vector3 replaces the device sensors (tests); empty = device sensors.
func _init(p_config: AimConfig, p_neutral_gravity: Vector3, gravity_source: Callable = Callable()) -> void:
	super(p_config)
	neutral_gravity = p_neutral_gravity
	_gravity_source = gravity_source


func update_aim(current: Vector2, delta: float) -> Vector2:
	var gravity := _read_gravity(delta)
	if gravity.length_squared() < MIN_GRAVITY_SQUARED:
		return clamp_to_cone(current)  # no sensor data: hold the aim
	var tilt := apply_dead_zone(tilt_angles(gravity, neutral_gravity), deg_to_rad(config.motion_dead_zone_deg))
	if invert_vertical:
		tilt.y = -tilt.y
	var gain := config.cone_half_angle_deg / config.motion_full_tilt_deg * sensitivity
	var target := clamp_to_cone(tilt * gain)
	return clamp_to_cone(current.lerp(target, smoothing_factor(delta, config.motion_smoothing_s)))


## Uses the current pose as the neutral pose.
func recenter() -> void:
	if _last_gravity.length_squared() >= MIN_GRAVITY_SQUARED:
		neutral_gravity = _last_gravity


## Most recent gravity reading (zero until the first sensor sample arrives).
func last_gravity() -> Vector3:
	return _last_gravity


## Tilt of `gravity` relative to `neutral`: x = roll (right positive), y = pitch (top edge
## towards the player positive), radians.
static func tilt_angles(gravity: Vector3, neutral: Vector3) -> Vector2:
	var roll := _roll(gravity) - _roll(neutral)
	var pitch := wrapf(_pitch(gravity) - _pitch(neutral), -PI, PI)
	return Vector2(roll, pitch)


## Shrinks the vector by `dead_zone` (radial dead zone without a jump at its edge).
static func apply_dead_zone(value: Vector2, dead_zone: float) -> Vector2:
	var magnitude := value.length()
	if magnitude <= dead_zone:
		return Vector2.ZERO
	return value * ((magnitude - dead_zone) / magnitude)


static func _roll(gravity: Vector3) -> float:
	return atan2(gravity.x, Vector2(gravity.y, gravity.z).length())


static func _pitch(gravity: Vector3) -> float:
	return atan2(gravity.z, -gravity.y)


func _read_gravity(delta: float) -> Vector3:
	if _gravity_source.is_valid():
		_last_gravity = _gravity_source.call()
		return _last_gravity
	var gravity := Input.get_gravity()
	if gravity.length_squared() < MIN_GRAVITY_SQUARED:
		var accelerometer := Input.get_accelerometer()
		if accelerometer.length_squared() >= MIN_GRAVITY_SQUARED:
			_filtered_accelerometer = _filtered_accelerometer.lerp(accelerometer,
					smoothing_factor(delta, config.accelerometer_filter_s))
			gravity = _filtered_accelerometer
	_last_gravity = gravity
	return gravity
