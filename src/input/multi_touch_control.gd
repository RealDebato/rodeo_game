class_name MultiTouchControl
extends Control
## Base class for touch widgets that must work with several fingers at once
## (joystick + fire button + focus slider).
##
## Godot's GUI emulates the mouse only for the first finger, so regular Buttons cannot be held
## while another finger steers. These widgets read InputEventScreenTouch/Drag directly in _input,
## claim the finger that started inside their rect and follow it by touch index until release.
## On the desktop, input_devices/pointing/emulate_touch_from_mouse turns the mouse into finger 0.
## Set mouse_filter = IGNORE on these controls so they never block regular GUI elements.

var _touch_index: int = -1


## True while a finger is held on this widget.
func is_touched() -> bool:
	return _touch_index != -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		if _touch_index != -1:
			_touch_index = -1
			_touch_ended()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1 and _accepts_touch_at(touch.position):
				_touch_index = touch.index
				_touch_began(_to_local(touch.position))
				get_viewport().set_input_as_handled()
		elif touch.index == _touch_index:
			_touch_index = -1
			_touch_ended()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_touch_moved(_to_local(drag.position))
			get_viewport().set_input_as_handled()


## Whether a new finger at `viewport_position` belongs to this widget. Default: inside the rect.
func _accepts_touch_at(viewport_position: Vector2) -> bool:
	return get_global_rect().has_point(viewport_position)


func _touch_began(_local_position: Vector2) -> void:
	pass


func _touch_moved(_local_position: Vector2) -> void:
	pass


func _touch_ended() -> void:
	pass


func _to_local(viewport_position: Vector2) -> Vector2:
	return viewport_position - global_position
