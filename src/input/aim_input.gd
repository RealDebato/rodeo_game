class_name AimInput
extends RefCounted
## Interface of all aiming methods.
##
## Aim angles are a Vector2 (x = yaw, right positive; y = pitch, up positive) in radians,
## relative to the laser boresight (laser -> debris centre). Each frame the game calls
## update_aim(current, delta) and turns the result into a beam direction with
## direction_from_angles(). Implementations only produce angles: they never touch the laser,
## the physics or the HUD, so the laser simulation is identical for every input method.

var config: AimConfig
## Player sensitivity (Settings.aim_sensitivity).
var sensitivity: float = 1.0
## Player option: invert the vertical axis.
var invert_vertical: bool = false


func _init(p_config: AimConfig) -> void:
	config = p_config


## Returns the new aim angles. Must stay inside the aim cone (see clamp_to_cone()).
func update_aim(current: Vector2, _delta: float) -> Vector2:
	return clamp_to_cone(current)


## Re-centres the input method on the player's current pose (no-op where meaningless).
func recenter() -> void:
	pass


## Limits aim angles to the cone half-angle.
func clamp_to_cone(angles: Vector2) -> Vector2:
	return angles.limit_length(deg_to_rad(config.cone_half_angle_deg))


## Unit beam direction for aim angles relative to a boresight basis (−Z = boresight).
static func direction_from_angles(boresight: Basis, angles: Vector2) -> Vector3:
	var cos_pitch := cos(angles.y)
	var local := Vector3(sin(angles.x) * cos_pitch, sin(angles.y), -cos(angles.x) * cos_pitch)
	return (boresight * local).normalized()


## Blend factor for frame-rate independent exponential smoothing with time constant tau.
static func smoothing_factor(delta: float, tau: float) -> float:
	if tau <= 0.0:
		return 1.0
	return 1.0 - exp(-delta / tau)
