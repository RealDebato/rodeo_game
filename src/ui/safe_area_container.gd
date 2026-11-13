class_name SafeAreaContainer
extends MarginContainer
## Keeps its children inside the display safe area (camera cut-outs, rounded corners) plus a
## fixed margin. Use as a full-rect root for HUD and menu layouts.

## Margin added on every side [px, in viewport coordinates].
@export var extra_margin: float = 16.0


func _ready() -> void:
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()


func _update_margins() -> void:
	var insets := [extra_margin, extra_margin, extra_margin, extra_margin]  # left, top, right, bottom
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if Platform.is_mobile() and screen_size.x > 0.0 and safe.size.x > 0.0:
		var to_viewport := get_viewport_rect().size / screen_size
		insets[0] += safe.position.x * to_viewport.x
		insets[1] += safe.position.y * to_viewport.y
		insets[2] += (screen_size.x - safe.end.x) * to_viewport.x
		insets[3] += (screen_size.y - safe.end.y) * to_viewport.y
	add_theme_constant_override("margin_left", roundi(insets[0]))
	add_theme_constant_override("margin_top", roundi(insets[1]))
	add_theme_constant_override("margin_right", roundi(insets[2]))
	add_theme_constant_override("margin_bottom", roundi(insets[3]))
