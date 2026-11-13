class_name InitialStateGenerator
extends RefCounted
## Creates initial rotational states.
##
## The direction of the initial angular momentum L is uniformly random; its magnitude is chosen
## so that the initial angular speed |ω| = |I⁻¹ L| equals the requested spin. (For a general
## tumble |ω| then varies slightly over time while L and the energy stay constant.)
## The start orientation is the identity unless randomize_orientation is set (Shoemake's method).


## New state for `definition` with initial |ω| = spin_deg_s, drawn from `rng`.
static func generate(definition: DebrisDefinition, spin_deg_s: float, rng: RandomNumberGenerator,
		randomize_orientation: bool = false) -> RotationalState:
	var state := RotationalState.new(definition.inertia_tensor())
	if randomize_orientation:
		state.orientation = random_orientation(rng)
	var direction := random_unit_vector(rng)
	# ω produced by a unit angular momentum along `direction`; scale L to reach the target |ω|.
	var omega_per_unit_l := (state.inertia_world().inverse() * direction).length()
	state.angular_momentum = direction * (deg_to_rad(spin_deg_s) / omega_per_unit_l)
	return state


## Uniformly distributed direction on the unit sphere.
static func random_unit_vector(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var phi := rng.randf() * TAU
	var radial := sqrt(1.0 - z * z)
	return Vector3(radial * cos(phi), radial * sin(phi), z)


## Uniformly distributed rotation.
static func random_orientation(rng: RandomNumberGenerator) -> Quaternion:
	var u1 := rng.randf()
	var u2 := rng.randf() * TAU
	var u3 := rng.randf() * TAU
	var a := sqrt(1.0 - u1)
	var b := sqrt(u1)
	return Quaternion(a * sin(u2), a * cos(u2), b * sin(u3), b * cos(u3)).normalized()
