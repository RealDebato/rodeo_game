class_name Reticle
extends Control
## Aim marker drawn where the laser beam would hit (projected to the screen by the game).

@export var on_target_color: Color = Color(0.45, 1.0, 1.0, 0.95)
@export var off_target_color: Color = Color(0.7, 0.8, 0.9, 0.45)
@export var ring_radius: float = 18.0

var _target: Vector2 = Vector2(-1000.0, -1000.0)
var _on_target: bool = false


func set_target(screen_position: Vector2, on_target: bool) -> void:
	if screen_position.is_equal_approx(_target) and on_target == _on_target:
		return
	_target = screen_position
	_on_target = on_target
	queue_redraw()


func _draw() -> void:
	var color := on_target_color if _on_target else off_target_color
	draw_arc(_target, ring_radius, 0.0, TAU, 32, color, 2.0, true)
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(_target + direction * (ring_radius + 5.0), _target + direction * (ring_radius + 16.0), color, 2.0, true)
	draw_circle(_target, 2.5, color)
