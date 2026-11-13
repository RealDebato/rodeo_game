class_name GameHUD
extends CanvasLayer
## In-game HUD: spin rate and its laser-induced change, red/green border-glow feedback, aim
## reticle, countdown, touch controls (joystick, FIRE, FOCUS, CENTER), pause menu and win screen.
## Pure presentation + raw control state; the game scene decides what the values mean.

signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal recenter_requested

const COLOR_SLOWING: Color = Color(0.25, 1.0, 0.45)
const COLOR_SPEEDING: Color = Color(1.0, 0.22, 0.15)
const COLOR_NEUTRAL: Color = Color(0.72, 0.9, 1.0)
const COLOR_SPIN_NORMAL: Color = Color(0.85, 0.97, 1.0)

## Spin change [°/s²] that drives the border glow to full intensity.
@export var glow_full_scale_deg_s2: float = 1.5
## Changes smaller than this [°/s²] count as "no effect" (neutral colour, no glow).
@export var change_dead_band_deg_s2: float = 0.01
## Glow fade-in / fade-out time constants [s].
@export var glow_attack_s: float = 0.08
@export var glow_release_s: float = 0.5
## Horizontal inset of the focus slider from the screen edge [px].
@export var focus_slider_edge_inset: float = 40.0
@export var focus_slider_width: float = 100.0

var _glow_intensity: float = 0.0
var _glow_color: Color = COLOR_SLOWING

@onready var _spin_title: Label = %SpinTitle
@onready var _spin_value: Label = %SpinValue
@onready var _change_value: Label = %ChangeValue
@onready var _countdown: Label = %Countdown
@onready var _border_glow: ColorRect = $BorderGlow
@onready var _glow_material: ShaderMaterial = $BorderGlow.material as ShaderMaterial
@onready var _reticle: Reticle = $Reticle
@onready var _controls: Control = %Controls
@onready var _joystick: TouchJoystick = %Joystick
@onready var _fire_button: FireButton = %FireButton
@onready var _focus_slider: TouchSlider = %FocusSlider
@onready var _recenter_button: TouchButton = %RecenterButton
@onready var _pause_button: Button = %PauseButton
@onready var _dimmer: ColorRect = %Dimmer
@onready var _pause_panel: PausePanel = %PausePanel
@onready var _result_panel: ResultPanel = %ResultPanel


func _ready() -> void:
	_pause_button.pressed.connect(pause_requested.emit)
	_recenter_button.tapped.connect(recenter_requested.emit)
	_pause_panel.resume_requested.connect(resume_requested.emit)
	_pause_panel.restart_requested.connect(restart_requested.emit)
	_pause_panel.menu_requested.connect(menu_requested.emit)
	_result_panel.restart_requested.connect(restart_requested.emit)
	_result_panel.menu_requested.connect(menu_requested.emit)
	_border_glow.visible = false
	_dimmer.hide()
	_pause_panel.hide()
	_result_panel.hide()
	_countdown.hide()
	set_motion_mode(false)


## Shows the win condition next to the spin read-out.
func set_target_hint(threshold_deg_s: float) -> void:
	_spin_title.text = "SPIN RATE   //   TARGET < %.1f °/s" % threshold_deg_s


## Motion aiming: hides the joystick, shows CENTER and moves the focus slider to the left side
## (where the joystick would be). Joystick aiming: slider on the right above FIRE.
func set_motion_mode(enabled: bool) -> void:
	_joystick.visible = not enabled
	_recenter_button.visible = enabled
	if enabled:
		_focus_slider.anchor_left = 0.0
		_focus_slider.anchor_right = 0.0
		_focus_slider.offset_left = focus_slider_edge_inset
		_focus_slider.offset_right = focus_slider_edge_inset + focus_slider_width
	else:
		_focus_slider.anchor_left = 1.0
		_focus_slider.anchor_right = 1.0
		_focus_slider.offset_left = -focus_slider_edge_inset - focus_slider_width
		_focus_slider.offset_right = -focus_slider_edge_inset


## Current joystick deflection, Vector2 in [-1, 1]², +y = up (zero when hidden).
func joystick_value() -> Vector2:
	return _joystick.value if _joystick.visible else Vector2.ZERO


## True while FIRE is held or continuous-wave mode is on.
func fire_active() -> bool:
	return _fire_button.is_firing()


func toggle_continuous_fire() -> void:
	_fire_button.set_continuous(not _fire_button.continuous)


func focus() -> float:
	return _focus_slider.value


func set_focus(value: float) -> void:
	_focus_slider.value = value


func set_reticle(screen_position: Vector2, on_target: bool) -> void:
	_reticle.set_target(screen_position, on_target)


## Big centred countdown text ("3", "2", "1", "GO!"); empty hides it.
func show_countdown(text: String) -> void:
	_countdown.visible = not text.is_empty()
	if _countdown.text != text:
		_countdown.text = text


## Updates the spin read-out and the border glow. `change_deg_s2` < 0: the laser slows the
## tumble (green); > 0: speeds it up (red). `below_target` colours the spin value green.
func update_spin(speed_deg_s: float, change_deg_s2: float, below_target: bool, delta: float) -> void:
	_spin_value.text = "%.2f °/s" % speed_deg_s
	_spin_value.modulate = COLOR_SLOWING if below_target else COLOR_SPIN_NORMAL
	_change_value.text = "%+.3f °/s²" % change_deg_s2
	var target_intensity := 0.0
	var target_color := COLOR_NEUTRAL
	if change_deg_s2 < -change_dead_band_deg_s2:
		target_color = COLOR_SLOWING
	elif change_deg_s2 > change_dead_band_deg_s2:
		target_color = COLOR_SPEEDING
	if target_color != COLOR_NEUTRAL:
		target_intensity = clampf(absf(change_deg_s2) / glow_full_scale_deg_s2, 0.0, 1.0)
		_glow_color = _glow_color.lerp(target_color, AimInput.smoothing_factor(delta, glow_attack_s))
	_change_value.modulate = target_color

	var tau := glow_attack_s if target_intensity > _glow_intensity else glow_release_s
	_glow_intensity = lerpf(_glow_intensity, target_intensity, AimInput.smoothing_factor(delta, tau))
	_border_glow.visible = _glow_intensity > 0.01
	if _border_glow.visible:
		# sqrt: small effects are still clearly visible.
		_glow_material.set_shader_parameter("intensity", sqrt(_glow_intensity))
		_glow_material.set_shader_parameter("glow_color", _glow_color)


func show_pause() -> void:
	_cancel_touches()
	_dimmer.show()
	_pause_panel.show()


func hide_pause() -> void:
	_pause_panel.hide()
	_dimmer.hide()


## Win screen. `rank` = 0-based highscore place or -1.
func show_result(time_s: float, rank: int, entry_count: int, best_time_s: float) -> void:
	_cancel_touches()
	_fire_button.set_continuous(false)
	_controls.hide()
	_pause_button.hide()
	_reticle.hide()
	_countdown.hide()
	_dimmer.show()
	_result_panel.show_result(time_s, rank, entry_count, best_time_s)


func _cancel_touches() -> void:
	for widget: MultiTouchControl in [_joystick, _fire_button, _focus_slider, _recenter_button]:
		widget.cancel_touch()
