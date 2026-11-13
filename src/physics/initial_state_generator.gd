class_name InitialStateGenerator
extends RefCounted
## Creates randomized initial rotational states within the limits of a DebrisDefinition.
##
## Orientation: uniformly random (Shoemake's method). Spin axis: uniformly random direction.
## Spin rate: uniform in [initial_spin_min_deg_s, initial_spin_max_deg_s] (initial |ω|; for a
## general tumble |ω| then varies slightly while L and the energy stay constant).


## New random state for `definition`, drawn from `rng` (seed it for reproducible states).
static func generate(definition: DebrisDefinition, rng: RandomNumberGenerator) -> RotationalState:
	var state := RotationalState.new(definition.inertia_tensor())
	state.orientation = random_orientation(rng)
	var speed := deg_to_rad(rng.randf_range(definition.initial_spin_min_deg_s, definition.initial_spin_max_deg_s))
	state.set_angular_velocity_world(random_unit_vector(rng) * speed)
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
