class_name TouchJoystick
extends MultiTouchControl
## (Not named VirtualJoystick: Godot 4.7 has a native class of that name.)
## Floating virtual joystick: the stick base appears where the thumb lands inside this control's
## rect (left part of the screen), the knob follows the thumb up to `radius`.
## Output: `value`, Vector2 in [-1, 1]², +x = right, +y = up. Zero when released.

@export var radius: float = 110.0
@export var knob_radius: float = 44.0
## Distance of the resting base from the bottom-left corner of the rect.
@export var rest_margin: float = 36.0
@export var base_color: Color = Color(0.35, 0.85, 1.0, 0.16)
@export var outline_color: Color = Color(0.45, 0.9, 1.0, 0.55)
@export var knob_color: Color = Color(0.55, 0.95, 1.0, 0.75)

var value: Vector2 = Vector2.ZERO

var _base_center: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	resized.connect(_reset_base)
	_reset_base()


func _touch_began(local_position: Vector2) -> void:
	var margin := Vector2(radius, radius)
	_base_center = local_position.clamp(margin, (size - margin).max(margin))
	_update_knob(local_position)


func _touch_moved(local_position: Vector2) -> void:
	_update_knob(local_position)


func _touch_ended() -> void:
	_reset_base()


func _draw() -> void:
	var alpha := 1.0 if is_touched() else 0.55
	draw_circle(_base_center, radius, Color(base_color, base_color.a * alpha))
	draw_arc(_base_center, radius, 0.0, TAU, 48, Color(outline_color, outline_color.a * alpha), 3.0, true)
	draw_circle(_base_center + _knob_offset, knob_radius, Color(knob_color, knob_color.a * alpha))


func _update_knob(local_position: Vector2) -> void:
	_knob_offset = (local_position - _base_center).limit_length(radius)
	value = Vector2(_knob_offset.x, -_knob_offset.y) / radius
	queue_redraw()


func _reset_base() -> void:
	_base_center = Vector2(rest_margin + radius, size.y - rest_margin - radius)
	_knob_offset = Vector2.ZERO
	value = Vector2.ZERO
	queue_redraw()
