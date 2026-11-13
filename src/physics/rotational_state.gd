class_name RotationalState
extends RefCounted
## Rotational state of a rigid body about its centre of mass. Pure physics, no scene access.
##
## Frames: "body" = the debris model frame in which the inertia tensor I_b is given;
## "world" = the inertial simulation frame. Units: SI (rad, s, kg·m², N·m·s).
##
## Primary state variables:
##   orientation q       body -> world rotation (unit quaternion)
##   angular_momentum L  world frame. Constant without external torque.
## Derived:
##   ω = R · I_b⁻¹ · Rᵀ · L      (R = rotation matrix of q)
## Keeping L (not ω) as the state variable makes torque-free tumbling (precession/nutation)
## emerge from the integration, and makes laser impulses exact: ΔL = r × J.
##
## Note: Godot vectors/quaternions are single precision (float32). Relative accuracy ~1e-7 per
## operation, which is ample for minute-long sessions.

var orientation: Quaternion = Quaternion.IDENTITY
var angular_momentum: Vector3 = Vector3.ZERO
var inertia_body: Basis = Basis.IDENTITY
var inertia_body_inverse: Basis = Basis.IDENTITY


func _init(p_inertia_body: Basis = Basis.IDENTITY) -> void:
	set_inertia_body(p_inertia_body)


## Sets the body-frame inertia tensor (symmetric, positive definite) [kg·m²].
func set_inertia_body(tensor: Basis) -> void:
	inertia_body = tensor
	inertia_body_inverse = tensor.inverse()


## Rotation matrix body -> world.
func rotation_basis() -> Basis:
	return Basis(orientation)


## Inertia tensor expressed in world axes: R · I_b · Rᵀ.
func inertia_world() -> Basis:
	var r := rotation_basis()
	return r * inertia_body * r.transposed()


## Angular velocity in world axes [rad/s].
func angular_velocity_world() -> Vector3:
	return RotationalState.angular_velocity_for(orientation, angular_momentum, inertia_body_inverse)


## Angular velocity in body axes [rad/s].
func angular_velocity_body() -> Vector3:
	return inertia_body_inverse * (rotation_basis().transposed() * angular_momentum)


## Magnitude of the angular velocity [rad/s].
func angular_speed() -> float:
	return angular_velocity_world().length()


## Rotational kinetic energy E = ½ ω·L [J].
func kinetic_energy() -> float:
	return 0.5 * angular_velocity_world().dot(angular_momentum)


## Sets L so that the body rotates with the given world-frame angular velocity [rad/s].
func set_angular_velocity_world(omega: Vector3) -> void:
	angular_momentum = inertia_world() * omega


## Adds an angular impulse ΔL [N·m·s] (world frame).
func apply_angular_impulse(delta_l: Vector3) -> void:
	angular_momentum += delta_l


## Applies a linear impulse J [N·s] at lever arm r (from the centre of mass, world frame [m]).
## Returns the resulting angular impulse ΔL = r × J.
func apply_impulse(lever_arm_world: Vector3, impulse_world: Vector3) -> Vector3:
	var delta_l := lever_arm_world.cross(impulse_world)
	angular_momentum += delta_l
	return delta_l


## Independent copy of this state.
func copy() -> RotationalState:
	var result := RotationalState.new(inertia_body)
	result.orientation = orientation
	result.angular_momentum = angular_momentum
	return result


## ω = R · I_b⁻¹ · Rᵀ · L for an arbitrary (not necessarily normalized) orientation.
static func angular_velocity_for(q: Quaternion, l_world: Vector3, inertia_inverse_body: Basis) -> Vector3:
	var r := Basis(q.normalized())
	return r * (inertia_inverse_body * (r.transposed() * l_world))
