class_name InputActions
extends RefCounted
## Keyboard actions for testing on the desktop (touch controls live in the HUD).
## Registered at runtime so project.godot stays readable.
##   WASD / arrows: aim   Space: fire   C: continuous fire on/off   Q / E: focus
##   Esc: pause / resume (ui_cancel)

const AIM_LEFT: StringName = &"aim_left"
const AIM_RIGHT: StringName = &"aim_right"
const AIM_UP: StringName = &"aim_up"
const AIM_DOWN: StringName = &"aim_down"
const FIRE: StringName = &"fire"
const FIRE_TOGGLE: StringName = &"fire_toggle"
const FOCUS_IN: StringName = &"focus_in"
const FOCUS_OUT: StringName = &"focus_out"


static func ensure_registered() -> void:
	_add(AIM_LEFT, [KEY_A, KEY_LEFT])
	_add(AIM_RIGHT, [KEY_D, KEY_RIGHT])
	_add(AIM_UP, [KEY_W, KEY_UP])
	_add(AIM_DOWN, [KEY_S, KEY_DOWN])
	_add(FIRE, [KEY_SPACE])
	_add(FIRE_TOGGLE, [KEY_C])
	_add(FOCUS_IN, [KEY_E])
	_add(FOCUS_OUT, [KEY_Q])


static func _add(action: StringName, keys: Array[Key]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
