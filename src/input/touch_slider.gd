class_name TouchSlider
extends MultiTouchControl
## Vertical multi-touch slider (bottom = 0, top = 1). The value jumps to the finger position,
## so it can be adjusted with the thumb while the other hand aims.

signal value_changed(new_value: float)

@export var label: String = "FOCUS"
@export var font_size: int = 18
@export var track_color: Color = Color(0.35, 0.85, 1.0, 0.18)
@export var fill_color: Color = Color(1.0, 0.3, 0.2, 0.7)
@export var outline_color: Color = Color(0.45, 0.9, 1.0, 0.55)
## Vertical space reserved for the label above the track.
@export var label_height: float = 30.0

var value: float = 0.8:
	set(new_value):
		var clamped := clampf(new_value, 0.0, 1.0)
		if is_equal_approx(clamped, value):
			return
		value = clamped
		value_changed.emit(value)
		queue_redraw()


func _touch_began(local_position: Vector2) -> void:
	_set_from_position(local_position)


func _touch_moved(local_position: Vector2) -> void:
	_set_from_position(local_position)


func _draw() -> void:
	var track := _track_rect()
	draw_rect(track, track_color, true)
	var fill_height := track.size.y * value
	draw_rect(Rect2(track.position.x, track.end.y - fill_height, track.size.x, fill_height), fill_color, true)
	draw_rect(track, outline_color, false, 2.0)
	var font := get_theme_default_font()
	var caption := "%s %d%%" % [label, roundi(value * 100.0)]
	var caption_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2((size.x - caption_size.x) * 0.5, font.get_ascent(font_size)),
			caption, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.75, 0.93, 1.0, 0.95))


func _track_rect() -> Rect2:
	var width := minf(size.x, 56.0)
	return Rect2((size.x - width) * 0.5, label_height, width, maxf(size.y - label_height, 1.0))


func _set_from_position(local_position: Vector2) -> void:
	var track := _track_rect()
	value = 1.0 - clampf((local_position.y - track.position.y) / track.size.y, 0.0, 1.0)
