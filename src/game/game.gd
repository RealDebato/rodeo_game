extends Node3D
## Gameplay scene: one debris object, laser aiming, ablation physics, mission flow, HUD.
##
## Per physics tick (fixed dt, physics/common/physics_ticks_per_second):
##   0. the servicer (camera + laser) advances on its slow orbit around the debris
##   1. active AimInput (joystick or motion) -> aim angles relative to the boresight -> beam
##   2. ray-cast the beam (also when not firing, for the reticle)
##   3. if the laser may fire (mission RUNNING) and fires on the debris: recoil force
##      (AblationModel), ΔL = r × J on the state, laser-induced change of |ω| for the HUD
##   4. integrate torque-free rotation (RotationalIntegrator), write orientation to the node
##   5. advance the GameSession (countdown, timer, win condition)
## The physics classes never see nodes or input; this script is the only place connecting them.
##
## Pausing pauses the whole scene tree; the pause menu and win screen run with
## process_mode = ALWAYS. Leaving the app (or losing focus) pauses automatically.

## Smoothing of the displayed spin change [s] (one tick alone is too noisy to read).
const CHANGE_SMOOTHING_S: float = 0.15
## Keyboard focus change per second (desktop testing).
const KEYBOARD_FOCUS_RATE: float = 0.6
## How long "GO!" stays on screen after the countdown [s].
const GO_DISPLAY_S: float = 0.8

@export var simulation_config: SimulationConfig
@export var aim_config: AimConfig
@export var game_rules: GameRules

var _rng := RandomNumberGenerator.new()
var _integrator: RotationalIntegrator
var _session: GameSession
var _aim_input: AimInput
var _aim_angles: Vector2 = Vector2.ZERO
var _boresight: Basis = Basis.IDENTITY
## Laser-induced change of |ω| [rad/s²], smoothed.
var _spin_change: float = 0.0
var _reticle_point: Vector3 = Vector3.ZERO
var _reticle_on_target: bool = false

@onready var _servicer: Node3D = $Servicer
@onready var _camera: Camera3D = $Servicer/Camera3D
@onready var _sun: DirectionalLight3D = $Sun
@onready var _fill_light: DirectionalLight3D = $Servicer/FillLight
@onready var _debris: Debris = $Debris
@onready var _laser: LaserEmitter = $Servicer/Laser
@onready var _hud: GameHUD = $GameHUD


func _ready() -> void:
	InputActions.ensure_registered()
	_camera.look_at(Vector3.ZERO)
	_sun.look_at_from_position(Vector3(30.0, 25.0, 20.0), Vector3.ZERO)
	# Fill light from the laser's side, so the surfaces the player aims at never go dark.
	# Child of the servicer, so it follows the orbit.
	_fill_light.look_at_from_position(_laser.global_position, _debris.global_position)

	# Per-game copy of the laser parameters with the player's power setting applied.
	var laser_config := _laser.config.duplicate() as LaserConfig
	laser_config.power_w *= Settings.laser_power_scale
	_laser.config = laser_config
	for problem: String in laser_config.validate():
		push_error("LaserConfig: %s" % problem)
	_hud.set_focus(laser_config.default_focus)
	_hud.set_target_hint(game_rules.completion_threshold_deg_s)

	_boresight = Basis.looking_at(_debris.global_position - _laser.global_position, Vector3.UP)
	_create_aim_input()
	_hud.pause_requested.connect(_pause_game)
	_hud.resume_requested.connect(_resume_game)
	_hud.restart_requested.connect(_restart_game)
	_hud.menu_requested.connect(_return_to_menu)
	_hud.recenter_requested.connect(_on_recenter_requested)

	_integrator = RotationalIntegrator.new(simulation_config.integrator_substeps)
	if simulation_config.random_seed != 0:
		_rng.seed = simulation_config.random_seed
	else:
		_rng.randomize()
	_session = GameSession.new(game_rules)
	_session.completed.connect(_on_mission_completed)
	_start_new_spin()


func _notification(what: int) -> void:
	if _session == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_pause_game()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if _session.state == GameSession.State.PAUSED:
				_resume_game()
			elif _session.state == GameSession.State.COMPLETED:
				_return_to_menu()
			else:
				_pause_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_pause_game()
	elif event.is_action_pressed(InputActions.FIRE_TOGGLE):
		_hud.toggle_continuous_fire()


func _physics_process(delta: float) -> void:
	# The servicer (camera + laser) circles the debris; the boresight follows it.
	_servicer.rotation.y = wrapf(_servicer.rotation.y + deg_to_rad(game_rules.servicer_orbit_deg_s) * delta, -PI, PI)
	_boresight = Basis.looking_at(_debris.global_position - _laser.global_position, Vector3.UP)

	_aim_angles = _aim_input.update_aim(_aim_angles, delta)
	_laser.aim_direction = AimInput.direction_from_angles(_boresight, _aim_angles)
	_laser.focus = _hud.focus()
	_laser.firing = _session.is_laser_enabled() \
			and (_hud.fire_active() or Input.is_action_pressed(InputActions.FIRE))

	var hit := _laser.cast_beam()
	var on_debris := hit != null and Debris.from_collider(hit.collider) == _debris
	var change := 0.0
	if _laser.firing and on_debris:
		change = _apply_laser_hit(hit, delta)
	_spin_change = lerpf(_spin_change, change, AimInput.smoothing_factor(delta, CHANGE_SMOOTHING_S))

	_integrator.step(_debris.state, delta)
	_debris.sync_transform()
	_session.advance(delta, rad_to_deg(_debris.state.angular_speed()))
	if not _session.is_laser_enabled():
		_laser.firing = false
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
	var speed_deg_s := rad_to_deg(_debris.state.angular_speed())
	_hud.update_spin(speed_deg_s, rad_to_deg(_spin_change),
			speed_deg_s < game_rules.completion_threshold_deg_s, delta)
	_hud.set_reticle(_camera.unproject_position(_reticle_point), _reticle_on_target)
	_update_countdown()


func _update_countdown() -> void:
	match _session.state:
		GameSession.State.COUNTDOWN:
			_hud.show_countdown(str(ceili(_session.countdown_remaining_s)))
		GameSession.State.RUNNING:
			_hud.show_countdown("GO!" if _session.elapsed_s < GO_DISPLAY_S else "")
		_:
			_hud.show_countdown("")


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
	_debris.state = InitialStateGenerator.generate(_debris.definition, game_rules.initial_spin_deg_s,
			_rng, game_rules.randomize_orientation)
	_debris.sync_transform()
	_spin_change = 0.0
	var l_dir := _debris.state.angular_momentum.normalized()
	print("[Game] new tumble: %.2f deg/s, L direction (%.2f, %.2f, %.2f), aim=%s" % [
		rad_to_deg(_debris.state.angular_speed()), l_dir.x, l_dir.y, l_dir.z,
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


func _on_mission_completed(time_s: float) -> void:
	var rank := Highscores.submit(time_s, _debris.definition.id, game_rules.initial_spin_deg_s)
	var entries := Highscores.entries()
	var best_time_s := float(entries[0]["time_s"]) if not entries.is_empty() else time_s
	print("[Game] mission complete in %s, rank %d" % [TimeFormat.mission_time(time_s), rank + 1])
	_hud.show_result(time_s, rank, entries.size(), best_time_s)


func _pause_game() -> void:
	if not _session.pause():
		return
	get_tree().paused = true
	_hud.show_pause()


func _resume_game() -> void:
	_session.resume()
	_hud.hide_pause()
	get_tree().paused = false


func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _return_to_menu() -> void:
	get_tree().paused = false
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)
