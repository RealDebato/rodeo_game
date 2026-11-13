class_name GameSession
extends RefCounted
## State machine and timing of one mission. Pure logic: no nodes, no input, no rendering.
##
##   COUNTDOWN -> RUNNING <-> PAUSED -> COMPLETED      (COUNTDOWN can be paused as well)
##
## The mission timer runs only in RUNNING. The mission is completed when |ω| stays below
## rules.completion_threshold_deg_s for rules.stabilization_s without interruption; the
## completion time is the mission time at that moment.

enum State { COUNTDOWN, RUNNING, PAUSED, COMPLETED }

signal state_changed(new_state: State)
signal completed(time_s: float)

var rules: GameRules
var state: State = State.COUNTDOWN
var countdown_remaining_s: float = 0.0
## Mission time since GO [s].
var elapsed_s: float = 0.0
## Uninterrupted time below the completion threshold [s].
var stable_s: float = 0.0

var _state_before_pause: State = State.COUNTDOWN


func _init(p_rules: GameRules) -> void:
	rules = p_rules
	countdown_remaining_s = rules.countdown_s
	if countdown_remaining_s <= 0.0:
		state = State.RUNNING


## Advances the session by one tick, given the current angular speed of the debris.
func advance(delta: float, angular_speed_deg_s: float) -> void:
	match state:
		State.COUNTDOWN:
			countdown_remaining_s -= delta
			if countdown_remaining_s <= 0.0:
				countdown_remaining_s = 0.0
				_set_state(State.RUNNING)
		State.RUNNING:
			elapsed_s += delta
			if angular_speed_deg_s < rules.completion_threshold_deg_s:
				stable_s += delta
				if stable_s >= rules.stabilization_s:
					_set_state(State.COMPLETED)
					completed.emit(elapsed_s)
			else:
				stable_s = 0.0


## The laser may only fire while the mission is running.
func is_laser_enabled() -> bool:
	return state == State.RUNNING


func can_pause() -> bool:
	return state == State.COUNTDOWN or state == State.RUNNING


## Pauses the session. Returns false if it cannot be paused (already paused or completed).
func pause() -> bool:
	if not can_pause():
		return false
	_state_before_pause = state
	_set_state(State.PAUSED)
	return true


func resume() -> void:
	if state == State.PAUSED:
		_set_state(_state_before_pause)


## 0..1 progress of the stabilisation hold.
func stabilization_progress() -> float:
	if rules.stabilization_s <= 0.0:
		return 1.0 if stable_s > 0.0 else 0.0
	return clampf(stable_s / rules.stabilization_s, 0.0, 1.0)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)
