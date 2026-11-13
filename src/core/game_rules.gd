class_name GameRules
extends Resource
## Rules of one de-tumbling mission (start state, countdown, win condition).

## Countdown before the laser and the mission timer start [s].
@export_range(0.0, 10.0, 0.5, "suffix:s") var countdown_s: float = 3.0
## Angular speed |ω| at the start of every mission [°/s]. Only the direction of the initial
## angular momentum is randomized.
@export_range(1.0, 180.0, 0.5, "suffix:°/s") var initial_spin_deg_s: float = 45.0
## Also randomize the start orientation (false = always the same attitude).
@export var randomize_orientation: bool = false
## The mission is won when |ω| stays below this value ... [°/s]
@export_range(0.1, 45.0, 0.1, "suffix:°/s") var completion_threshold_deg_s: float = 4.0
## ... for this long without interruption [s]. 0 = win the moment it drops below.
@export_range(0.0, 10.0, 0.1, "suffix:s") var stabilization_s: float = 1.0
## The servicer (camera + laser) circles the debris about the vertical axis at this rate [°/s].
## Needed for winnability: recoil forces can hardly create torque about the laser's own line of
## sight, so a fixed viewpoint leaves the momentum component along it unreachable.
## A moving line of sight makes every component reachable. 0 = fixed viewpoint.
@export_range(0.0, 30.0, 0.5, "suffix:°/s") var servicer_orbit_deg_s: float = 5.0
