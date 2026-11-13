class_name AblationModel
extends RefCounted
## Laser-ablation recoil model. Pure physics: no scene, input or rendering access.
##
## Ablated material leaves the surface roughly along the local outward normal n, so the recoil
## on the target points along −n – independent of the beam direction d except through the
## absorbed power. That is what makes aiming strategic: the same beam on a tilted panel pushes
## in a different direction and creates a different torque.
##
##   cos_i  = max(0, −d·n)                                incidence (0: grazing or back side)
##   r_spot = lerp(r_defocused, r_focused, focus)         beam radius on target [m]
##   I      = P · cos_i / (π r_spot²)                     irradiance on the surface [W/m²]
##   C_m    = C_max · I / (I + I_half)                    momentum coupling [N/W], saturating
##   F      = −n · C_m · η · P · cos_i · gain             recoil force [N]
##   J      = F · Δt                                      recoil impulse per time step [N·s]
##
## η = SurfaceMaterial.ablation_efficiency, gain = LaserConfig.gameplay_gain.
## Torque follows outside this class: ΔL = r × J (RotationalState.apply_impulse).


## Incidence factor cos_i = max(0, −d·n) for unit beam direction d and unit outward normal n.
static func incidence_factor(beam_direction: Vector3, surface_normal: Vector3) -> float:
	return maxf(0.0, -beam_direction.dot(surface_normal))


## Beam radius on the target [m] for focus in [0, 1].
static func spot_radius(config: LaserConfig, focus: float) -> float:
	return lerpf(config.spot_radius_defocused_m, config.spot_radius_focused_m, clampf(focus, 0.0, 1.0))


## Irradiance on the surface [W/m²].
static func irradiance(config: LaserConfig, focus: float, incidence: float) -> float:
	var radius := spot_radius(config, focus)
	return config.power_w * incidence / (PI * radius * radius)


## Momentum coupling coefficient C_m [N/W] at the given irradiance.
static func coupling_coefficient(config: LaserConfig, irradiance_w_m2: float) -> float:
	return config.max_coupling_n_per_w * irradiance_w_m2 / (irradiance_w_m2 + config.half_coupling_irradiance_w_m2)


## Recoil force on the target [N] (world frame), including the gameplay gain.
static func recoil_force(config: LaserConfig, efficiency: float, beam_direction: Vector3,
		surface_normal: Vector3, focus: float) -> Vector3:
	var incidence := incidence_factor(beam_direction, surface_normal)
	if incidence <= 0.0:
		return Vector3.ZERO
	var coupling := coupling_coefficient(config, irradiance(config, focus, incidence))
	var magnitude := coupling * efficiency * config.power_w * incidence * config.gameplay_gain
	return -surface_normal.normalized() * magnitude


## Recoil impulse over one time step [N·s].
static func recoil_impulse(config: LaserConfig, efficiency: float, beam_direction: Vector3,
		surface_normal: Vector3, focus: float, dt: float) -> Vector3:
	return recoil_force(config, efficiency, beam_direction, surface_normal, focus) * dt
