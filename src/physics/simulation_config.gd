class_name SimulationConfig
extends Resource
## Settings of the rotational simulation loop.
##
## The simulation runs in _physics_process at the project's physics tick rate
## (physics/common/physics_ticks_per_second, default 60 Hz) with a fixed time step.

## RK4 sub-steps per physics tick. 1 is accurate to ~1e-9 rad per tick at a few °/s.
@export_range(1, 16) var integrator_substeps: int = 1
## Seed for the random initial rotational state. 0 = new random seed every game.
@export var random_seed: int = 0
