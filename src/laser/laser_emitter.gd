class_name LaserEmitter
extends Node3D
## The servicer's ablation laser: casts the beam against debris colliders and draws beam + spot.
##
## Knows nothing about input methods (it only receives aim_direction, focus and firing) and
## nothing about the recoil physics (AblationModel). The node position is the beam origin.

## Result of a beam ray-cast (world space).
class Hit extends RefCounted:
	var point: Vector3
	var normal: Vector3
	var collider: Object
	var shape_index: int

	func _init(p_point: Vector3, p_normal: Vector3, p_collider: Object, p_shape_index: int) -> void:
		point = p_point
		normal = p_normal
		collider = p_collider
		shape_index = p_shape_index


## Small offset that lifts the spot marker off the surface to avoid z-fighting [m].
const SPOT_SURFACE_OFFSET_M: float = 0.03
## Spot opacity at minimum / maximum focus: a defocused spot is larger and fainter.
const SPOT_ALPHA_DEFOCUSED: float = 0.3
const SPOT_ALPHA_FOCUSED: float = 0.9

@export var config: LaserConfig
## Physics layers the beam can hit (layer 2 = "debris").
@export_flags_3d_physics var collision_mask: int = 2

## Unit beam direction in world space.
var aim_direction: Vector3 = Vector3.FORWARD
## 0 = widest spot, 1 = sharpest spot.
var focus: float = 0.8:
	set(value):
		focus = clampf(value, 0.0, 1.0)
var firing: bool = false

var _query := PhysicsRayQueryParameters3D.new()

@onready var _beam: MeshInstance3D = $Beam
@onready var _spot: MeshInstance3D = $Spot
@onready var _spot_material: StandardMaterial3D = (_spot.mesh as PrimitiveMesh).material as StandardMaterial3D


## Points the beam from the emitter towards a world-space target.
func aim_at(target: Vector3) -> void:
	var to_target := target - global_position
	if to_target.length_squared() > 1e-8:
		aim_direction = to_target.normalized()


## Ray-casts the beam. Returns null if nothing on `collision_mask` is within range.
func cast_beam() -> Hit:
	_query.from = global_position
	_query.to = global_position + aim_direction * config.max_range_m
	_query.collision_mask = collision_mask
	var result := get_world_3d().direct_space_state.intersect_ray(_query)
	if result.is_empty():
		return null
	return Hit.new(result["position"], result["normal"], result["collider"], result["shape"])


## Shows/hides and places the beam and the impact spot for the current tick.
func update_visuals(hit: Hit) -> void:
	_beam.visible = firing
	_spot.visible = firing and hit != null
	if not firing:
		return
	var start := global_position
	var end := hit.point if hit != null else start + aim_direction * config.max_range_m
	_beam.global_transform = Transform3D(_basis_along(aim_direction, 1.0, start.distance_to(end)), (start + end) * 0.5)
	if hit != null:
		var radius := AblationModel.spot_radius(config, focus)
		_spot.global_transform = Transform3D(_basis_along(hit.normal, radius, 1.0),
				hit.point + hit.normal * SPOT_SURFACE_OFFSET_M)
		_spot_material.albedo_color.a = lerpf(SPOT_ALPHA_DEFOCUSED, SPOT_ALPHA_FOCUSED, focus)


## Basis whose Y axis is `axis` (scaled by axial_scale), X/Z perpendicular (scaled by radial_scale).
## Cylinder meshes are Y-aligned, so this orients the beam and the spot disc.
static func _basis_along(axis: Vector3, radial_scale: float, axial_scale: float) -> Basis:
	var helper := Vector3.UP if absf(axis.y) < 0.99 else Vector3.RIGHT
	var x := axis.cross(helper).normalized()
	var z := x.cross(axis)
	return Basis(x * radial_scale, axis * axial_scale, z * radial_scale)
