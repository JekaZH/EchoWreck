@tool
class_name WorldGroundMesh
extends MeshInstance3D
## Коллизия пола под визуальным мешем (PlaneMesh, BoxMesh, terrain mesh).
## Слой 1 = world — тот же, что у PlayerPhysicsSettings / dash ground mask.


@export_flags_3d_physics var collision_layer: int = 1
@export_range(0.1, 2.0, 0.05) var collision_thickness_m: float = 1.0
## Если не ноль — размер бокса коллизии вручную (X, Y толщина, Z).
@export var collision_size_override: Vector3 = Vector3.ZERO


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_ground_collision()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_ground_collision()


func _ensure_ground_collision() -> void:
	if get_node_or_null("GroundCollision") != null:
		return
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = collision_layer
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _get_collision_box_size()
	shape_node.shape = box
	shape_node.position = Vector3(0.0, -box.size.y * 0.5, 0.0)
	body.add_child(shape_node)
	add_child(body)


func _get_collision_box_size() -> Vector3:
	if collision_size_override.length_squared() > 0.0001:
		var size := collision_size_override
		if size.y < 0.05:
			size.y = collision_thickness_m
		return size
	if mesh == null:
		return Vector3(50.0, collision_thickness_m, 50.0)
	if mesh is PlaneMesh:
		var plane := mesh as PlaneMesh
		return Vector3(plane.size.x, collision_thickness_m, plane.size.y)
	if mesh is BoxMesh:
		var box_mesh := mesh as BoxMesh
		var size := box_mesh.size
		return Vector3(size.x, maxf(size.y, collision_thickness_m), size.z)
	var aabb := mesh.get_aabb()
	return Vector3(
		maxf(aabb.size.x, 1.0),
		maxf(aabb.size.y, collision_thickness_m),
		maxf(aabb.size.z, 1.0)
	)
