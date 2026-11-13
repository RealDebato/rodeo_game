class_name DebrisDefinition
extends Resource
## Data describing one debris object: model, mass properties and surface.
## (The start spin is a mission rule, see GameRules.)
##
## A new debris object (other satellite, rocket stage, ...) is a new .tres using this script plus
## a model scene – no code changes. Body frame = the model scene's local frame, in metres.
## The model scene must contain collision shapes on physics layer 2 ("debris") for the laser.

## Stable identifier, used for highscores and saves.
@export var id: String = ""
## Name shown to the player.
@export var display_name: String = ""
@export_multiline var description: String = ""
## Visual + collision model, in body-frame coordinates.
@export var model_scene: PackedScene

@export_group("Mass properties")
## Total mass [kg]. Not used by the rotational model; kept for future translational effects.
@export var mass_kg: float = 1000.0
## Centre of mass in model coordinates [m]. The model is shifted so this point is the pivot.
@export var center_of_mass_m: Vector3 = Vector3.ZERO
## Diagonal elements (Ixx, Iyy, Izz) of the inertia tensor about the centre of mass [kg·m²].
@export var inertia_diagonal_kg_m2: Vector3 = Vector3(1000.0, 1000.0, 1000.0)
## Off-diagonal tensor elements (Ixy, Ixz, Iyz) [kg·m²]. The tensor is
## [[Ixx, Ixy, Ixz], [Ixy, Iyy, Iyz], [Ixz, Iyz, Izz]].
@export var inertia_off_diagonal_kg_m2: Vector3 = Vector3.ZERO

@export_group("Surface")
## Material used for every surface (surface zones are a future feature).
@export var surface_material: SurfaceMaterial


## Inertia tensor about the centre of mass in body-frame axes [kg·m²].
func inertia_tensor() -> Basis:
	var d := inertia_diagonal_kg_m2
	var o := inertia_off_diagonal_kg_m2
	# Basis(x, y, z) takes columns; the tensor is symmetric, so columns equal rows.
	return Basis(Vector3(d.x, o.x, o.y), Vector3(o.x, d.y, o.z), Vector3(o.y, o.z, d.z))


## Returns human-readable problems with this definition (empty = valid).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if model_scene == null:
		errors.append("model_scene is not set")
	if surface_material == null:
		errors.append("surface_material is not set")
	if mass_kg <= 0.0:
		errors.append("mass_kg must be > 0")
	var d := inertia_diagonal_kg_m2
	var o := inertia_off_diagonal_kg_m2
	if d.x <= 0.0 or d.y <= 0.0 or d.z <= 0.0:
		errors.append("inertia diagonal elements must be > 0")
	elif d.x + d.y < d.z or d.x + d.z < d.y or d.y + d.z < d.x:
		errors.append("inertia diagonal violates the triangle inequality (not a physical body)")
	# Positive definite <=> all leading principal minors > 0 (Sylvester's criterion).
	if d.x * d.y - o.x * o.x <= 0.0 or inertia_tensor().determinant() <= 0.0:
		errors.append("inertia tensor is not positive definite")
	return errors
