extends Node3D
## Milestone 1 smoke test: verifies the platform features the game depends on.
##
## Checks on a real device that
##   - the Mobile renderer draws a lit 3D scene (rotating placeholder),
##   - landscape orientation, UI scaling and the display safe area behave,
##   - multi-touch events arrive (needed for joystick + fire button at the same time),
##   - accelerometer / gravity / gyroscope deliver data (needed for motion aiming),
##   - app lifecycle notifications arrive (needed to auto-pause the game).
##
## Temporary scene. It is replaced as the main scene by the main menu in Milestone 5,
## but kept as a diagnostics tool for device testing (Milestone 6).

const REFRESH_INTERVAL_S: float = 0.1
const SPIN_RATE_DEG_S: float = 20.0
const SPIN_AXIS: Vector3 = Vector3(0.3, 1.0, 0.2)
const NO_DATA_EPSILON: float = 1e-6

var _active_touches: Dictionary[int, Vector2] = {}
var _max_simultaneous_touches: int = 0
var _pause_count: int = 0
var _resume_count: int = 0
var _back_requests: int = 0
var _refresh_timer: float = 0.0

@onready var _placeholder: Node3D = $Placeholder
@onready var _sun: DirectionalLight3D = $Sun
@onready var _info: Label = $HUD/Info
@onready var _touch_marker: Control = $HUD/TouchMarker


func _ready() -> void:
	_sun.look_at_from_position(Vector3(6.0, 5.0, 6.0), Vector3.ZERO)
	_touch_marker.visible = false
	# Shows up in `adb logcat -s godot` and in the Godot editor output panel.
	print("[DeviceCheck] %s | %s | renderer=%s | adapter=%s | screen=%s" % [
		OS.get_name(),
		OS.get_model_name(),
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
		DisplayServer.screen_get_size(),
	])


func _process(delta: float) -> void:
	# Visual-only spin to prove the 3D pipeline works. Real rotational dynamics arrive in Milestone 2.
	_placeholder.rotate(SPIN_AXIS.normalized(), deg_to_rad(SPIN_RATE_DEG_S) * delta)

	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL_S
		_info.text = _build_report()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_active_touches[touch.index] = touch.position
		else:
			_active_touches.erase(touch.index)
		_max_simultaneous_touches = maxi(_max_simultaneous_touches, _active_touches.size())
		_show_marker(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_active_touches[drag.index] = drag.position
		_show_marker(drag.position)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_pause_count += 1
			print("[DeviceCheck] application paused")
		NOTIFICATION_APPLICATION_RESUMED:
			_resume_count += 1
			print("[DeviceCheck] application resumed")
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button / gesture. With application/config/quit_on_go_back = true
			# (Godot's default) the app quits after this notification.
			_back_requests += 1
			print("[DeviceCheck] back requested")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _show_marker(screen_position: Vector2) -> void:
	_touch_marker.visible = true
	_touch_marker.position = screen_position - _touch_marker.size * 0.5


func _build_report() -> String:
	var lines: PackedStringArray = []
	lines.append("LASER DE-TUMBLING  -  DEVICE CHECK  v%s" % ProjectSettings.get_setting("application/config/version"))
	lines.append("")
	lines.append("FPS:  %d" % int(Engine.get_frames_per_second()))
	lines.append("Renderer:  %s  /  %s" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
	])
	lines.append("Platform:  %s  /  %s" % [OS.get_name(), OS.get_model_name()])
	lines.append("Screen:  %s px   Viewport: %s" % [
		DisplayServer.screen_get_size(),
		get_viewport().get_visible_rect().size,
	])
	lines.append("Safe area:  %s" % DisplayServer.get_display_safe_area())
	lines.append("")
	lines.append("Accelerometer:  %s  m/s2" % _format_vector(Input.get_accelerometer()))
	lines.append("Gravity:  %s  m/s2" % _format_vector(Input.get_gravity()))
	lines.append("Gyroscope:  %s  rad/s" % _format_vector(Input.get_gyroscope()))
	lines.append("")
	lines.append("Touches:  %d active,  max %d simultaneous" % [_active_touches.size(), _max_simultaneous_touches])
	lines.append("Lifecycle:  paused %d  /  resumed %d  /  back %d" % [_pause_count, _resume_count, _back_requests])
	return "\n".join(lines)


func _format_vector(value: Vector3) -> String:
	if value.length_squared() < NO_DATA_EPSILON:
		return "(no data)"
	return "%+6.2f  %+6.2f  %+6.2f" % [value.x, value.y, value.z]
