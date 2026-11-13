class_name RotationalIntegrator
extends RefCounted
## Advances a RotationalState in time under torque-free rigid-body motion.
##
## Model: Euler's rotation equations in their angular-momentum form. Without external torque
## the world-frame angular momentum L is constant; only the orientation evolves:
##   dq/dt = ½ · ω(q) ⊗ q,   ω(q) = R(q) · I_b⁻¹ · R(q)ᵀ · L
## Method: classical 4th-order Runge-Kutta on the quaternion, renormalized after every step.
## Laser impulses are applied between steps (impulsive approximation: ΔL = r × J per tick).
##
## For more sophisticated models (gravity-gradient torque, flexible appendages, ...) subclass
## and override step(); callers only depend on step().

var substeps: int = 1


func _init(p_substeps: int = 1) -> void:
	substeps = maxi(1, p_substeps)


## Advances `state` by `dt` seconds.
func step(state: RotationalState, dt: float) -> void:
	var h := dt / float(substeps)
	for _i: int in range(substeps):
		state.orientation = _rk4(state.orientation, state.angular_momentum, state.inertia_body_inverse, h)


static func _rk4(q: Quaternion, l_world: Vector3, inertia_inverse_body: Basis, h: float) -> Quaternion:
	var k1 := _derivative(q, l_world, inertia_inverse_body)
	var k2 := _derivative(q + k1 * (0.5 * h), l_world, inertia_inverse_body)
	var k3 := _derivative(q + k2 * (0.5 * h), l_world, inertia_inverse_body)
	var k4 := _derivative(q + k3 * h, l_world, inertia_inverse_body)
	return (q + (k1 + k2 * 2.0 + k3 * 2.0 + k4) * (h / 6.0)).normalized()


## dq/dt = ½ ω ⊗ q with ω in world axes (left multiplication).
static func _derivative(q: Quaternion, l_world: Vector3, inertia_inverse_body: Basis) -> Quaternion:
	var qn := q.normalized()
	var w := RotationalState.angular_velocity_for(qn, l_world, inertia_inverse_body)
	return (Quaternion(w.x, w.y, w.z, 0.0) * qn) * 0.5
