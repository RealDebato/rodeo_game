extends Node3D
## Gameplay scene: one debris object, laser aiming, ablation physics and HUD feedback.
##
## Per physics tick (fixed dt, physics/common/physics_ticks_per_second):
##   1. active AimInput (joystick or motion) -> aim angles -> beam direction
##   2. ray-cast the beam (also when not firing, for the reticle)
##   3. if firing on the debris: recoil force (AblationModel), ΔL = r × J on the state,
##      and the laser-induced change of the spin rate for the feedback display
##   4. integrate torque-free rotation (RotationalIntegrator), write orientation to the node
## The physics classes never see nodes or input; this script is the only place connecting them.
## Countdown, completion threshold, timer and pause arrive in Milestone 4.

## Smoothing of the displayed spin change [s] (one tick alone is too noisy to read).
const CHANGE_SMOOTHING_S: float = 0.15
## Keyboard focus change per second (desktop testing).
const KEYBOARD_FOCUS_RATE: float = 0.6

@export var simulation_config: SimulationConfig
@export var aim_config: AimConfig

var _rng := RandomNumberGenerator.new()
var _integrator: RotationalIntegrator
var _aim_input: AimInput
var _aim_angles: Vector2 = Vector2.ZERO
var _boresight: Basis = Basis.IDENTITY
## Laser-induced change of |ω| [rad/s²], smoothed.
var _spin_change: float = 0.0
var _reticle_point: Vector3 = Vector3.ZERO
var _reticle_on_target: bool = false

@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _debris: Debris = $Debris
@onready var _laser: LaserEmitter = $Laser
@onready var _hud: GameHUD = $GameHUD


func _ready() -> void:
	InputActions.ensure_registered()
	_camera.look_at(Vector3.ZERO)
	_sun.look_at_from_position(Vector3(30.0, 25.0, 20.0), Vector3.ZERO)

	# Per-game copy of the laser parameters with the player's power setting applied.
	var laser_config := _laser.config.duplicate() as LaserConfig
	laser_config.power_w *= Settings.laser_power_scale
	_laser.config = laser_config
	for problem: String in laser_config.validate():
		push_error("LaserConfig: %s" % problem)
	_hud.set_focus(laser_config.default_focus)

	_boresight = Basis.looking_at(_debris.global_position - _laser.global_position, Vector3.UP)
	_create_aim_input()
	_hud.menu_requested.connect(_return_to_menu)
	_hud.recenter_requested.connect(_on_recenter_requested)

	_integrator = RotationalIntegrator.new(simulation_config.integrator_substeps)
	if simulation_config.random_seed != 0:
		_rng.seed = simulation_config.random_seed
	else:
		_rng.randomize()
	_start_new_spin()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_return_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_return_to_menu()


func _physics_process(delta: float) -> void:
	_aim_angles = _aim_input.update_aim(_aim_angles, delta)
	_laser.aim_direction = AimInput.direction_from_angles(_boresight, _aim_angles)
	_laser.focus = _hud.focus()
	_laser.firing = _hud.fire_pressed() or Input.is_action_pressed(InputActions.FIRE)

	var hit := _laser.cast_beam()
	var on_debris := hit != null and Debris.from_collider(hit.collider) == _debris
	var change := 0.0
	if _laser.firing and on_debris:
		change = _apply_laser_hit(hit, delta)
	_spin_change = lerpf(_spin_change, change, AimInput.smoothing_factor(delta, CHANGE_SMOOTHING_S))

	_integrator.step(_debris.state, delta)
	_debris.sync_transform()
	_laser.update_visuals(hit if on_debris else null)

	_reticle_on_target = on_debris
	if on_debris:
		_reticle_point = hit.point
	else:
		_reticle_point = _laser.global_position + _laser.aim_direction * _laser.global_position.distance_to(_debris.global_position)


func _process(delta: float) -> void:
	var focus_keys := Input.get_axis(InputActions.FOCUS_OUT, InputActions.FOCUS_IN)
	if focus_keys != 0.0:
		_hud.set_focus(_hud.focus() + focus_keys * KEYBOARD_FOCUS_RATE * delta)
	_hud.update_spin(rad_to_deg(_debris.state.angular_speed()), rad_to_deg(_spin_change), delta)
	_hud.set_reticle(_camera.unproject_position(_reticle_point), _reticle_on_target)


func _create_aim_input() -> void:
	var motion := Settings.aim_method == Settings.AIM_MOTION
	if motion:
		_aim_input = MotionAimInput.new(aim_config, Settings.motion_neutral_gravity)
	else:
		_aim_input = JoystickAimInput.new(aim_config, _stick_vector)
	_aim_input.sensitivity = Settings.aim_sensitivity
	_aim_input.invert_vertical = Settings.invert_vertical
	_hud.set_motion_mode(motion)


## Joystick deflection, or the keyboard (WASD/arrows) when the stick is idle.
func _stick_vector() -> Vector2:
	var stick := _hud.joystick_value()
	var keys := Input.get_vector(InputActions.AIM_LEFT, InputActions.AIM_RIGHT, InputActions.AIM_DOWN, InputActions.AIM_UP)
	return stick if stick.length_squared() >= keys.length_squared() else keys


func _on_recenter_requested() -> void:
	_aim_input.recenter()
	if _aim_input is MotionAimInput:
		var gravity := (_aim_input as MotionAimInput).last_gravity()
		if gravity.length_squared() > MotionAimInput.MIN_GRAVITY_SQUARED:
			Settings.calibrate_motion(gravity)


func _start_new_spin() -> void:
	_debris.state = InitialStateGenerator.generate(_debris.definition, _rng)
	_debris.sync_transform()
	_spin_change = 0.0
	var axis := _debris.state.angular_velocity_body().normalized()
	print("[Game] new tumble: %.2f deg/s about body axis (%.2f, %.2f, %.2f), aim=%s" % [
		rad_to_deg(_debris.state.angular_speed()), axis.x, axis.y, axis.z,
		"motion" if _aim_input is MotionAimInput else "joystick"])


## Applies one tick of laser recoil. Returns the resulting change of |ω| per second [rad/s²].
func _apply_laser_hit(hit: LaserEmitter.Hit, delta: float) -> float:
	var state := _debris.state
	var surface := _debris.surface_material_for(hit.collider, hit.shape_index)
	var force := AblationModel.recoil_force(_laser.config, surface.ablation_efficiency,
			_laser.aim_direction, hit.normal, _laser.focus)
	var speed_before := state.angular_speed()
	state.apply_impulse(_debris.lever_arm_to(hit.point), force * delta)
	return (state.angular_speed() - speed_before) / delta


func _return_to_menu() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)
