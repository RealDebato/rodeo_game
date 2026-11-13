extends TestCase
## Aiming: angle -> direction mapping, cone limit, joystick rate control, tilt mapping.

const DT: float = 1.0 / 60.0


static func _config() -> AimConfig:
	var config := AimConfig.new()
	config.joystick_smoothing_s = 0.0
	config.motion_smoothing_s = 0.0
	return config


func test_direction_from_angles() -> void:
	var boresight := Basis.IDENTITY  # looks along -Z
	assert_vec_near(AimInput.direction_from_angles(boresight, Vector2.ZERO), Vector3(0.0, 0.0, -1.0), 1e-6)
	assert_true(AimInput.direction_from_angles(boresight, Vector2(0.2, 0.0)).x > 0.0, "yaw + aims right")
	assert_true(AimInput.direction_from_angles(boresight, Vector2(0.0, 0.2)).y > 0.0, "pitch + aims up")
	assert_near(AimInput.direction_from_angles(boresight, Vector2(0.3, -0.4)).length(), 1.0, 1e-6)


func test_aim_is_clamped_to_cone() -> void:
	var config := _config()
	var input := AimInput.new(config)
	var limit := deg_to_rad(config.cone_half_angle_deg)
	assert_near(input.clamp_to_cone(Vector2(5.0, 5.0)).length(), limit, 1e-6)
	assert_vec_near(Vector3(input.clamp_to_cone(Vector2(0.1, 0.0)).x, 0.0, 0.0), Vector3(0.1, 0.0, 0.0), 1e-6)


func test_joystick_full_deflection_moves_at_max_rate() -> void:
	var config := _config()
	config.cone_half_angle_deg = 60.0
	var input := JoystickAimInput.new(config, func() -> Vector2: return Vector2(1.0, 0.0))
	var angles := Vector2.ZERO
	for _i: int in range(60):  # 1 s
		angles = input.update_aim(angles, DT)
	assert_near(rad_to_deg(angles.x), config.joystick_max_rate_deg_s, 0.1)
	assert_near(angles.y, 0.0, 1e-6)


func test_joystick_released_holds_aim_and_dead_zone_ignores_small_input() -> void:
	var config := _config()
	var input := JoystickAimInput.new(config, func() -> Vector2: return Vector2(0.05, 0.0))
	var start := Vector2(0.1, -0.05)
	assert_vec_near(Vector3(input.update_aim(start, DT).x, input.update_aim(start, DT).y, 0.0),
			Vector3(start.x, start.y, 0.0), 1e-6)


func test_joystick_sensitivity_and_invert() -> void:
	var config := _config()
	var input := JoystickAimInput.new(config, func() -> Vector2: return Vector2(0.0, 1.0))
	input.sensitivity = 0.5
	input.invert_vertical = true
	var angles := input.update_aim(Vector2.ZERO, 0.1)
	assert_near(rad_to_deg(angles.y), -config.joystick_max_rate_deg_s * 0.5 * 0.1, 1e-3)


func test_joystick_response_curve_is_finer_near_centre() -> void:
	var half := JoystickAimInput.shape(Vector2(0.5, 0.0), 0.0, 2.0).x
	assert_near(half, 0.25, 1e-6)
	assert_near(JoystickAimInput.shape(Vector2(3.0, 0.0), 0.0, 2.0).x, 1.0, 1e-6)


func test_tilt_angles_relative_to_neutral() -> void:
	var neutral := Vector3(0.0, -8.0, -5.6)  # landscape, tilted back
	assert_vec_near(Vector3(MotionAimInput.tilt_angles(neutral, neutral).x, MotionAimInput.tilt_angles(neutral, neutral).y, 0.0), Vector3.ZERO, 1e-6)
	# Steering-wheel roll to the right (device rotates -10° about its z axis): gravity seen by the
	# device rotates +10°, gaining a +x component -> roll > 0.
	var rolled := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(10.0)) * neutral
	var roll_tilt := MotionAimInput.tilt_angles(rolled, neutral)
	assert_true(roll_tilt.x > 0.0, "roll right -> aim right (%s)" % roll_tilt)
	# Top edge towards the player: gravity gains +z -> pitch > 0.
	var pitched := Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(-10.0)) * neutral
	var pitch_tilt := MotionAimInput.tilt_angles(pitched, neutral)
	assert_true(pitch_tilt.y > 0.0, "top edge towards player -> aim up (%s)" % pitch_tilt)
	assert_near(rad_to_deg(pitch_tilt.y), 10.0, 0.01)
	assert_near(pitch_tilt.x, 0.0, 1e-5)


func test_motion_full_tilt_reaches_cone_edge() -> void:
	var config := _config()
	config.motion_dead_zone_deg = 0.0
	var neutral := Vector3(0.0, -9.81, 0.0)
	var tilted := Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(-config.motion_full_tilt_deg * 0.5)) * neutral
	var input := MotionAimInput.new(config, neutral, func() -> Vector3: return tilted)
	var angles := input.update_aim(Vector2.ZERO, DT)
	assert_near(rad_to_deg(angles.y), config.cone_half_angle_deg * 0.5, 0.05, "half tilt -> half cone")


func test_motion_recenter_uses_current_pose() -> void:
	var config := _config()
	var pose := Vector3(0.5, -9.0, -3.0)
	var input := MotionAimInput.new(config, Vector3(0.0, -9.81, 0.0), func() -> Vector3: return pose)
	input.update_aim(Vector2.ZERO, DT)
	input.recenter()
	assert_vec_near(input.neutral_gravity, pose, 1e-6)
	var angles := input.update_aim(Vector2(0.2, 0.2), DT)
	assert_near(angles.length(), 0.0, 1e-5, "after recentering the aim returns to the boresight")


func test_no_sensor_data_holds_aim() -> void:
	var input := MotionAimInput.new(_config(), Vector3(0.0, -9.81, 0.0), func() -> Vector3: return Vector3.ZERO)
	var angles := input.update_aim(Vector2(0.1, 0.05), DT)
	assert_near(angles.distance_to(Vector2(0.1, 0.05)), 0.0, 1e-6)
