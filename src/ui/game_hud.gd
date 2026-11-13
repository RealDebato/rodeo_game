class_name GameHUD
extends CanvasLayer
## In-game HUD: spin rate and its laser-induced change, red/green border-glow feedback, the aim
## reticle and the touch controls (joystick, fire, focus, recenter).
## Pure presentation + raw control state; the game scene decides what the values mean.

signal menu_requested
signal recenter_requested

const COLOR_SLOWING: Color = Color(0.25, 1.0, 0.45)
const COLOR_SPEEDING: Color = Color(1.0, 0.22, 0.15)
const COLOR_NEUTRAL: Color = Color(0.72, 0.9, 1.0)

## Spin change [°/s²] that drives the border glow to full intensity.
@export var glow_full_scale_deg_s2: float = 0.3
## Changes smaller than this [°/s²] count as "no effect" (neutral colour, no glow).
@export var change_dead_band_deg_s2: float = 0.003
## Glow fade-in / fade-out time constants [s].
@export var glow_attack_s: float = 0.08
@export var glow_release_s: float = 0.5

var _glow_intensity: float = 0.0
var _glow_color: Color = COLOR_SLOWING

@onready var _spin_value: Label = %SpinValue
@onready var _change_value: Label = %ChangeValue
@onready var _border_glow: ColorRect = $BorderGlow
@onready var _glow_material: ShaderMaterial = $BorderGlow.material as ShaderMaterial
@onready var _reticle: Reticle = $Reticle
@onready var _joystick: TouchJoystick = %Joystick
@onready var _fire_button: TouchButton = %FireButton
@onready var _focus_slider: TouchSlider = %FocusSlider
@onready var _recenter_button: TouchButton = %RecenterButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	_menu_button.pressed.connect(menu_requested.emit)
	_recenter_button.tapped.connect(recenter_requested.emit)
	_border_glow.visible = false
	set_motion_mode(false)


## Motion aiming hides the joystick and shows the RECENTER button instead.
func set_motion_mode(enabled: bool) -> void:
	_joystick.visible = not enabled
	_recenter_button.visible = enabled


## Current joystick deflection, Vector2 in [-1, 1]², +y = up (zero when hidden).
func joystick_value() -> Vector2:
	return _joystick.value if _joystick.visible else Vector2.ZERO


func fire_pressed() -> bool:
	return _fire_button.pressed


func focus() -> float:
	return _focus_slider.value


func set_focus(value: float) -> void:
	_focus_slider.value = value


func set_reticle(screen_position: Vector2, on_target: bool) -> void:
	_reticle.set_target(screen_position, on_target)


## Updates the spin read-out and the border glow. `change_deg_s2` < 0 means the laser slows the
## tumble (green), > 0 speeds it up (red).
func update_spin(speed_deg_s: float, change_deg_s2: float, delta: float) -> void:
	_spin_value.text = "%.2f °/s" % speed_deg_s
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
