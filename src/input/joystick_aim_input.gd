class_name JoystickAimInput
extends AimInput
## Virtual-joystick aiming with rate control, like the look stick of mobile FPS games:
## the stick deflection sets the angular *speed* of the aim; releasing the stick holds the aim.
## Deflection passes a dead zone and a power response curve (fine control near the centre),
## then the rate is smoothed so the motion is predictable and free of jitter.

## Callable returning the stick deflection, Vector2 in [-1, 1]², +y = up.
var _source: Callable
var _rate: Vector2 = Vector2.ZERO


func _init(p_config: AimConfig, source: Callable) -> void:
	super(p_config)
	_source = source


func update_aim(current: Vector2, delta: float) -> Vector2:
	var stick: Vector2 = _source.call()
	if invert_vertical:
		stick.y = -stick.y
	var shaped := shape(stick, config.joystick_dead_zone, config.joystick_response_exponent)
	var target_rate := shaped * deg_to_rad(config.joystick_max_rate_deg_s) * sensitivity
	_rate = _rate.lerp(target_rate, smoothing_factor(delta, config.joystick_smoothing_s))
	return clamp_to_cone(current + _rate * delta)


## Dead zone + power curve on the deflection magnitude, keeping the direction.
static func shape(stick: Vector2, dead_zone: float, exponent: float) -> Vector2:
	var magnitude := minf(stick.length(), 1.0)
	if magnitude <= dead_zone:
		return Vector2.ZERO
	var scaled := (magnitude - dead_zone) / (1.0 - dead_zone)
	return stick.normalized() * pow(scaled, exponent)
