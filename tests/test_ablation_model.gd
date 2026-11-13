extends TestCase
## Laser-ablation recoil model.

const NORMAL := Vector3(0.0, 0.0, 1.0)
const HEAD_ON := Vector3(0.0, 0.0, -1.0)


static func _config() -> LaserConfig:
	return LaserConfig.new()  # script defaults, see laser_config.gd


func test_default_config_is_valid() -> void:
	var errors := _config().validate()
	assert_true(errors.is_empty(), ", ".join(errors))


func test_recoil_points_into_surface_along_negative_normal() -> void:
	var oblique := Vector3(0.6, 0.0, -0.8)
	var force := AblationModel.recoil_force(_config(), 1.0, oblique, NORMAL, 0.8)
	assert_true(force.length() > 0.0, "oblique hit must produce recoil")
	assert_vec_near(force.normalized(), -NORMAL, 1e-6, "recoil follows the surface normal, not the beam")


func test_no_recoil_for_grazing_or_back_side_hits() -> void:
	var config := _config()
	assert_vec_near(AblationModel.recoil_force(config, 1.0, Vector3(1.0, 0.0, 0.0), NORMAL, 1.0), Vector3.ZERO, 1e-9)
	assert_vec_near(AblationModel.recoil_force(config, 1.0, Vector3(0.0, 0.0, 1.0), NORMAL, 1.0), Vector3.ZERO, 1e-9)


func test_more_focus_gives_more_recoil() -> void:
	var config := _config()
	var low := AblationModel.recoil_force(config, 1.0, HEAD_ON, NORMAL, 0.2).length()
	var mid := AblationModel.recoil_force(config, 1.0, HEAD_ON, NORMAL, 0.5).length()
	var high := AblationModel.recoil_force(config, 1.0, HEAD_ON, NORMAL, 1.0).length()
	assert_true(low < mid and mid < high, "%s < %s < %s" % [low, mid, high])
	assert_true(AblationModel.spot_radius(config, 1.0) < AblationModel.spot_radius(config, 0.0))


func test_oblique_incidence_reduces_recoil() -> void:
	var config := _config()
	var head_on := AblationModel.recoil_force(config, 1.0, HEAD_ON, NORMAL, 0.8).length()
	var at_60_deg := AblationModel.recoil_force(config, 1.0, Vector3(sin(PI / 3.0), 0.0, -cos(PI / 3.0)), NORMAL, 0.8).length()
	assert_true(at_60_deg < head_on)


func test_recoil_scales_linearly_with_efficiency_and_gain() -> void:
	var config := _config()
	var base := AblationModel.recoil_force(config, 1.0, HEAD_ON, NORMAL, 0.8).length()
	assert_near(AblationModel.recoil_force(config, 0.5, HEAD_ON, NORMAL, 0.8).length(), base * 0.5, base * 1e-5)
	config.gameplay_gain *= 2.0
	assert_near(AblationModel.recoil_force(config, 1.0, HEAD_ON, NORMAL, 0.8).length(), base * 2.0, base * 1e-5)


func test_physical_magnitude_without_gain() -> void:
	# P = 10 kW, r = 5 cm, head-on: I = 1.2732e6 W/m², C_m = 5e-5 · I/(I + 3e4) = 4.885e-5 N/W
	# -> F = C_m · P = 0.4885 N (no gameplay gain).
	var config := _config()
	config.gameplay_gain = 1.0
	assert_near(AblationModel.recoil_force(config, 1.0, HEAD_ON, NORMAL, 1.0).length(), 0.4885, 1e-3)


func test_impulse_is_force_times_dt() -> void:
	var config := _config()
	var force := AblationModel.recoil_force(config, 1.0, HEAD_ON, NORMAL, 0.8)
	var impulse := AblationModel.recoil_impulse(config, 1.0, HEAD_ON, NORMAL, 0.8, 0.02)
	assert_vec_near(impulse, force * 0.02, 1e-6)
