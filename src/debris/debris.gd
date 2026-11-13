class_name Debris
extends Node3D
## Scene representation of one debris object, driven by a RotationalState.
##
## The node origin is the centre of mass: the model scene from the DebrisDefinition is
## instantiated as a child and shifted by −center_of_mass_m. The node only *displays* the
## simulated orientation (sync_transform); it never integrates physics itself.
## Collision shapes inside the model scene (layer 2 "debris") are what the laser ray-casts hit.

## Data for this object (model, inertia, surface, spin limits).
@export var definition: DebrisDefinition

## Current rotational state. Replaced wholesale when a new game starts.
var state: RotationalState

var _model: Node3D


func _ready() -> void:
	assert(definition != null, "Debris needs a DebrisDefinition")
	for problem: String in definition.validate():
		push_error("DebrisDefinition '%s': %s" % [definition.id, problem])
	_model = definition.model_scene.instantiate() as Node3D
	_model.name = "Model"
	_model.position = -definition.center_of_mass_m
	add_child(_model)
	state = RotationalState.new(definition.inertia_tensor())
	sync_transform()


## Writes the simulated orientation to the node (call after every integration step).
func sync_transform() -> void:
	quaternion = state.orientation


## Lever arm r from the centre of mass to a world-space point [m].
func lever_arm_to(point_world: Vector3) -> Vector3:
	return point_world - global_position


## Surface material at a collider hit. Uniform for now; per-zone materials hook in here later.
func surface_material_for(_collider: Object, _shape_index: int) -> SurfaceMaterial:
	return definition.surface_material


## The Debris that owns `collider` (a collision body inside its model), or null.
static func from_collider(collider: Object) -> Debris:
	var node := collider as Node
	while node != null:
		if node is Debris:
			return node as Debris
		node = node.get_parent()
	return null
