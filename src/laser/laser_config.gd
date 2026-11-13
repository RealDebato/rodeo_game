class_name LaserConfig
extends Resource
## Tunable parameters of the servicer's ablation laser (SI units).
##
## The equations that use these values are documented in AblationModel.

@export_group("Laser")
## Optical output power P [W].
@export_range(100.0, 100000.0, 100.0, "suffix:W") var power_w: float = 10000.0
## Maximum beam range [m].
@export_range(1.0, 1000.0, 1.0, "suffix:m") var max_range_m: float = 200.0

@export_group("Focus")
## Beam radius on the target at full focus (focus = 1) [m].
@export_range(0.001, 1.0, 0.001, "suffix:m") var spot_radius_focused_m: float = 0.05
## Beam radius on the target at minimum focus (focus = 0) [m].
@export_range(0.01, 5.0, 0.01, "suffix:m") var spot_radius_defocused_m: float = 1.0
## Focus at the start of a game (0 = widest spot, 1 = sharpest spot).
@export_range(0.0, 1.0, 0.01) var default_focus: float = 0.8

@export_group("Ablation")
## Peak momentum coupling coefficient C_max [N/W]. Laser ablation of metals: ~1e-5 .. 1e-4 N/W.
@export var max_coupling_n_per_w: float = 5.0e-5
## Irradiance at which the coupling reaches half of C_max [W/m²]. Below it, ablation is weak.
@export var half_coupling_irradiance_w_m2: float = 3.0e4

@export_group("Gameplay")
## Dimensionless gain on the recoil force. Real laser de-tumbling of Envisat takes days to weeks;
## this compresses one session to minutes. It scales magnitudes only: directions, lever arms and
## therefore whether a shot slows or speeds up the tumble stay physical. 1 = physical.
@export_range(1.0, 2000.0, 1.0) var gameplay_gain: float = 500.0


## Returns human-readable problems with this configuration (empty = valid).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if power_w <= 0.0:
		errors.append("power_w must be > 0")
	if spot_radius_focused_m <= 0.0:
		errors.append("spot_radius_focused_m must be > 0")
	if spot_radius_defocused_m < spot_radius_focused_m:
		errors.append("spot_radius_defocused_m must be >= spot_radius_focused_m")
	if max_coupling_n_per_w <= 0.0:
		errors.append("max_coupling_n_per_w must be > 0")
	if half_coupling_irradiance_w_m2 <= 0.0:
		errors.append("half_coupling_irradiance_w_m2 must be > 0")
	if gameplay_gain <= 0.0:
		errors.append("gameplay_gain must be > 0")
	return errors
