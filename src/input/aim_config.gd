class_name AimConfig
extends Resource
## Tunables for laser aiming. The player's sensitivity setting multiplies the rate/gain values.

## Maximum angle between the beam and the boresight (laser -> debris centre) [°].
@export_range(5.0, 60.0, 0.5, "suffix:°") var cone_half_angle_deg: float = 30.0

@export_group("Virtual joystick")
## Aim angular speed at full stick deflection and sensitivity 1 [°/s].
@export_range(5.0, 180.0, 1.0, "suffix:°/s") var joystick_max_rate_deg_s: float = 40.0
## Response curve exponent (1 = linear; > 1 = finer control near the centre).
@export_range(1.0, 3.0, 0.05) var joystick_response_exponent: float = 1.8
## Stick deflection (0..1) ignored around the centre.
@export_range(0.0, 0.5, 0.01) var joystick_dead_zone: float = 0.08
## Time constant of the aim-rate smoothing [s].
@export_range(0.0, 0.5, 0.005, "suffix:s") var joystick_smoothing_s: float = 0.05

@export_group("Motion sensors")
## Phone tilt (from the neutral pose) that moves the aim to the edge of the cone at sensitivity 1 [°].
@export_range(5.0, 60.0, 0.5, "suffix:°") var motion_full_tilt_deg: float = 18.0
## Tilt ignored around the neutral pose, against hand tremor [°].
@export_range(0.0, 5.0, 0.1, "suffix:°") var motion_dead_zone_deg: float = 1.0
## Time constant of the aim smoothing [s].
@export_range(0.0, 0.5, 0.005, "suffix:s") var motion_smoothing_s: float = 0.08
## Low-pass time constant when only the raw accelerometer is available (no gravity sensor) [s].
@export_range(0.01, 1.0, 0.01, "suffix:s") var accelerometer_filter_s: float = 0.15
