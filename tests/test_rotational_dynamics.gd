extends TestCase
## Torque-free rigid-body rotation: conservation laws and analytic special cases.

const DT: float = 1.0 / 60.0


static func _envisat_like_inertia() -> Basis:
	return Basis(Vector3(17023.0, 0.0, 0.0), Vector3(0.0, 124826.0, 0.0), Vector3(0.0, 0.0, 129112.0))


static func _general_tumble() -> RotationalState:
	var state := RotationalState.new(_envisat_like_inertia())
	state.orientation = Quaternion(Vector3(1.0, 2.0, 3.0).normalized(), 0.7)
	state.set_angular_velocity_world(Vector3(0.02, -0.04, 0.03))
	return state


func test_angular_velocity_is_consistent_with_inertia() -> void:
	var state := _general_tumble()
	# L = I_world · ω must hold for the derived ω.
	assert_vec_near(state.inertia_world() * state.angular_velocity_world(), state.angular_momentum, 1e-2)
	# Body and world angular velocity describe the same vector.
	assert_vec_near(state.rotation_basis() * state.angular_velocity_body(), state.angular_velocity_world(), 1e-7)


func test_energy_and_momentum_conserved_during_tumble() -> void:
	var state := _general_tumble()
	var l0 := state.angular_momentum
	var e0 := state.kinetic_energy()
	var w0 := state.angular_velocity_world()
	var integrator := RotationalIntegrator.new()
	for _i: int in range(6000):  # 100 s
		integrator.step(state, DT)
	assert_vec_near(state.angular_momentum, l0, 1e-6, "L must be constant without torque")
	assert_near(state.kinetic_energy(), e0, e0 * 1e-4, "rotational energy drift > 0.01 %")
	assert_near(state.orientation.length(), 1.0, 1e-6, "quaternion must stay normalized")
	assert_true(state.angular_velocity_world().distance_to(w0) > 1e-3,
			"omega should change (precess) for a general tumble")


func test_spin_about_principal_axis_matches_analytic_rotation() -> void:
	var state := RotationalState.new(_envisat_like_inertia())
	var rate := 0.05  # rad/s about body z (= world z at identity orientation), major axis
	state.set_angular_velocity_world(Vector3(0.0, 0.0, rate))
	var integrator := RotationalIntegrator.new()
	for _i: int in range(6000):  # 100 s -> 5 rad
		integrator.step(state, DT)
	var expected := Quaternion(Vector3(0.0, 0.0, 1.0), rate * 100.0)
	assert_near(state.orientation.angle_to(expected), 0.0, 1e-3, "rotation angle after 100 s")
	assert_vec_near(state.angular_velocity_world(), Vector3(0.0, 0.0, rate), 1e-6, "steady spin axis")


func test_substeps_agree_with_single_step() -> void:
	var a := _general_tumble()
	var b := a.copy()
	var single := RotationalIntegrator.new(1)
	var multi := RotationalIntegrator.new(8)
	for _i: int in range(600):
		single.step(a, DT)
		multi.step(b, DT)
	assert_near(a.orientation.angle_to(b.orientation), 0.0, 1e-4)
