class_name SurfaceMaterial
extends Resource
## Ablation-relevant properties of a debris surface.
##
## Milestone 2 uses one material for the whole object (DebrisDefinition.surface_material).
## Later milestones attach different materials to individual surface zones (reflective panels,
## fragile parts, ...). Add such properties here so the laser model reads them in one place.

## Human-readable name for UI / debug output.
@export var display_name: String = "Aluminium"
## Multiplier on the momentum coupling (1 = reference aluminium; reflective surfaces < 1).
@export_range(0.0, 2.0, 0.01) var ablation_efficiency: float = 1.0
