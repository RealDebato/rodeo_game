extends TestCase
## Mission state machine: countdown, timer, win condition with stabilisation, pause.

## Exactly representable in binary, so summed durations hit the thresholds without rounding.
const DT: float = 0.125


static func _rules() -> GameRules:
	var rules := GameRules.new()
	rules.countdown_s = 3.0
	rules.completion_threshold_deg_s = 4.0
	rules.stabilization_s = 1.0
	return rules


static func _run(session: GameSession, seconds: float, speed_deg_s: float) -> void:
	for _i: int in range(roundi(seconds / DT)):
		session.advance(DT, speed_deg_s)


func test_countdown_then_running() -> void:
	var session := GameSession.new(_rules())
	assert_true(session.state == GameSession.State.COUNTDOWN)
	assert_true(not session.is_laser_enabled(), "no laser during countdown")
	_run(session, 2.875, 45.0)
	assert_true(session.state == GameSession.State.COUNTDOWN)
	_run(session, 0.125, 45.0)
	assert_true(session.state == GameSession.State.RUNNING)
	assert_true(session.is_laser_enabled())


func test_win_requires_stable_hold_below_threshold() -> void:
	var session := GameSession.new(_rules())
	var completion_times: Array[float] = []
	session.completed.connect(func(t: float) -> void: completion_times.append(t))
	_run(session, 3.0, 45.0)        # countdown
	_run(session, 10.0, 20.0)       # running, too fast
	_run(session, 0.5, 3.0)         # below, but not long enough...
	_run(session, 0.25, 5.0)        # ...interrupted: hold resets
	assert_true(session.state == GameSession.State.RUNNING, "interrupted hold must not win")
	_run(session, 1.0, 3.0)         # stable for 1 s
	assert_true(session.state == GameSession.State.COMPLETED)
	assert_true(completion_times.size() == 1, "completed emitted once")
	if completion_times.size() == 1:
		assert_near(completion_times[0], 11.75, 1e-6, "time counts from GO, including the hold")
	assert_true(not session.is_laser_enabled())


func test_zero_stabilization_wins_immediately_below_threshold() -> void:
	var rules := _rules()
	rules.stabilization_s = 0.0
	rules.countdown_s = 0.0
	var session := GameSession.new(rules)
	session.advance(DT, 3.9)
	assert_true(session.state == GameSession.State.COMPLETED)


func test_pause_freezes_time_and_resume_restores_state() -> void:
	var session := GameSession.new(_rules())
	_run(session, 3.0, 45.0)
	_run(session, 2.0, 45.0)
	assert_true(session.pause())
	assert_true(not session.is_laser_enabled())
	_run(session, 5.0, 45.0)
	assert_near(session.elapsed_s, 2.0, 1e-3, "paused time does not count")
	session.resume()
	assert_true(session.state == GameSession.State.RUNNING)
	assert_true(not session.pause() or session.state == GameSession.State.PAUSED)


func test_cannot_pause_after_completion() -> void:
	var rules := _rules()
	rules.countdown_s = 0.0
	rules.stabilization_s = 0.0
	var session := GameSession.new(rules)
	session.advance(DT, 1.0)
	assert_true(not session.pause())


func test_time_format() -> void:
	assert_true(TimeFormat.mission_time(83.42) == "1:23.4", TimeFormat.mission_time(83.42))
	assert_true(TimeFormat.mission_time(59.96) == "1:00.0", TimeFormat.mission_time(59.96))
	assert_true(TimeFormat.mission_time(5.0) == "0:05.0", TimeFormat.mission_time(5.0))
