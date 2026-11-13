extends TestCase
## Angular impulse ΔL = r × J and its effect on the tumble.


static func _spinning_about_z(rate: float) -> RotationalState:
	var state := RotationalState.new(Basis(Vector3(17023.0, 0.0, 0.0), Vector3(0.0, 124826.0, 0.0), Vector3(0.0, 0.0, 129112.0)))
	state.set_angular_velocity_world(Vector3(0.0, 0.0, rate))
	return state


func test_angular_impulse_equals_r_cross_j() -> void:
	var state := RotationalState.new()
	state.angular_momentum = Vector3(10.0, -5.0, 3.0)
	var r := Vector3(1.0, 2.0, 3.0)
	var j := Vector3(0.5, -1.0, 2.0)
	var delta_l := state.apply_impulse(r, j)
	assert_vec_near(delta_l, r.cross(j), 1e-6)
	assert_vec_near(state.angular_momentum, Vector3(10.0, -5.0, 3.0) + r.cross(j), 1e-5)


func test_impulse_through_centre_of_mass_has_no_rotational_effect() -> void:
	var state := _spinning_about_z(0.05)
	var l0 := state.angular_momentum
	state.apply_impulse(Vector3(2.0, 0.0, 0.0), Vector3(-3.0, 0.0, 0.0))
	assert_vec_near(state.angular_momentum, l0, 1e-6)


func test_opposing_torque_slows_and_aligned_torque_speeds_up() -> void:
	# Body spins +z. A push along -y at +x gives torque r × J along -z (opposing): slows down.
	# The same push at -x gives torque along +z (aligned): speeds up.
	var j := Vector3(0.0, -10.0, 0.0)
	var slowed := _spinning_about_z(0.05)
	var e0 := slowed.kinetic_energy()
	slowed.apply_impulse(Vector3(10.0, 0.0, 0.0), j)
	assert_true(slowed.kinetic_energy() < e0, "impulse on +x side should reduce energy")
	assert_true(slowed.angular_speed() < 0.05, "impulse on +x side should reduce |omega|")

	var sped_up := _spinning_about_z(0.05)
	sped_up.apply_impulse(Vector3(-10.0, 0.0, 0.0), j)
	assert_true(sped_up.kinetic_energy() > e0, "impulse on -x side should increase energy")
	assert_true(sped_up.angular_speed() > 0.05, "impulse on -x side should increase |omega|")


func test_larger_lever_arm_gives_larger_effect() -> void:
	var j := Vector3(0.0, -10.0, 0.0)
	var near := _spinning_about_z(0.05)
	var far := _spinning_about_z(0.05)
	near.apply_impulse(Vector3(2.0, 0.0, 0.0), j)
	far.apply_impulse(Vector3(12.0, 0.0, 0.0), j)
	assert_true(far.angular_speed() < near.angular_speed())
