class_name FireButton
extends TouchButton
## Laser trigger. Hold to fire; double-tap to toggle continuous-wave mode (fires without holding)
## and double-tap again to switch it off. While continuous, the button shows "CW" and stays lit.

signal continuous_changed(enabled: bool)

## Maximum gap between the end of the first tap and the start of the second [s].
@export var double_tap_window_s: float = 0.35
## A touch shorter than this counts as a tap [s].
@export var tap_max_duration_s: float = 0.3
@export var continuous_text: String = "CW"

var continuous: bool = false

var _hold_text: String = ""
var _press_start_ms: int = 0
var _last_tap_end_ms: int = -100000
## True while the current press is the second tap of a double tap (it must not start a new one).
var _press_toggled: bool = false


func _ready() -> void:
	_hold_text = text


## True while the laser should fire (held or continuous).
func is_firing() -> bool:
	return pressed or continuous


func set_continuous(enabled: bool) -> void:
	if continuous == enabled:
		return
	continuous = enabled
	text = continuous_text if enabled else _hold_text
	continuous_changed.emit(enabled)
	queue_redraw()


func _touch_began(local_position: Vector2) -> void:
	var now := Time.get_ticks_msec()
	_press_toggled = now - _last_tap_end_ms <= roundi(double_tap_window_s * 1000.0)
	if _press_toggled:
		set_continuous(not continuous)
	_last_tap_end_ms = -100000
	_press_start_ms = now
	super._touch_began(local_position)


func _touch_ended() -> void:
	var now := Time.get_ticks_msec()
	if not _press_toggled and now - _press_start_ms <= roundi(tap_max_duration_s * 1000.0):
		_last_tap_end_ms = now  # may become the first tap of a double tap
	_press_toggled = false
	super._touch_ended()


func _is_lit() -> bool:
	return pressed or continuous


func _draw() -> void:
	super._draw()
	if continuous:
		var center := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_arc(center, r + 6.0, 0.0, TAU, 48, Color(color, 0.9), 4.0, true)
