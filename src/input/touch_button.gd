class_name TouchButton
extends MultiTouchControl
## Round multi-touch button (works while other fingers use the joystick or slider).
## `pressed` is true while held; `tapped` fires on release.

signal pressed_changed(is_pressed: bool)
signal tapped

@export var text: String = "FIRE"
@export var font_size: int = 28
@export var color: Color = Color(1.0, 0.25, 0.2, 0.75)
@export var text_color: Color = Color(1.0, 1.0, 1.0, 0.95)

var pressed: bool = false


func _touch_began(_local_position: Vector2) -> void:
	_set_pressed(true)


func _touch_ended() -> void:
	var was_pressed := pressed
	_set_pressed(false)
	if was_pressed:
		tapped.emit()


func _accepts_touch_at(viewport_position: Vector2) -> bool:
	var center := global_position + size * 0.5
	return viewport_position.distance_to(center) <= minf(size.x, size.y) * 0.5


func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var fill := Color(color, color.a * (0.9 if pressed else 0.35))
	draw_circle(center, r, fill)
	draw_arc(center, r - 1.5, 0.0, TAU, 48, Color(color, 1.0), 3.0, true)
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - 2.0),
			text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_color)


func _set_pressed(value: bool) -> void:
	if pressed == value:
		return
	pressed = value
	pressed_changed.emit(value)
	queue_redraw()
