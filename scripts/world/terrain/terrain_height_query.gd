class_name TerrainHeightQuery
extends RefCounted

const TERRAIN_READY_FRAMES := 6
const RAY_UP := 80.0
const RAY_DOWN := 120.0


static func find_terrain(from_node: Node) -> Terrain3D:
	if from_node == null:
		return null
	var tree := from_node.get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("world_terrain"):
		if n is Terrain3D:
			return n as Terrain3D
	return null


static func when_terrain_ready(from_node: Node) -> void:
	var terrain := find_terrain(from_node)
	if terrain is Terrain3DWorld:
		var tw := terrain as Terrain3DWorld
		var tree := from_node.get_tree() if from_node else null
		if tree != null and not tw.is_layout_ready():
			var deadline_ms := Time.get_ticks_msec() + 8000
			while Time.get_ticks_msec() < deadline_ms:
				if tw.is_layout_ready():
					break
				await tree.process_frame
			if not tw.is_layout_ready():
				await tw.layout_ready
		if tree != null:
			for _i in 120:
				if tw.has_active_regions():
					break
				await tree.process_frame
		await until_physics_ground_at(from_node, 0.0, 0.0, 80)
		return
	var tree := from_node.get_tree() if from_node else null
	if tree == null:
		return
	for _i in TERRAIN_READY_FRAMES:
		await tree.process_frame
	await until_ground_resolved(from_node, 0.0, 0.0)


static func until_ground_resolved(from_node: Node, world_x: float, world_z: float, max_attempts: int = 24) -> void:
	var tree := from_node.get_tree() if from_node else null
	if tree == null:
		return
	for _attempt in max_attempts:
		var y := get_ground_y(from_node, world_x, world_z, NAN)
		if not is_nan(y):
			return
		await tree.process_frame


static func get_ground_y(from_node: Node, world_x: float, world_z: float, fallback_y: float = 0.0) -> float:
	var ray_y := _raycast_ground_y(from_node, world_x, world_z, NAN)
	if not is_nan(ray_y):
		return ray_y
	var terrain := find_terrain(from_node)
	if terrain != null and terrain.data != null:
		var h: float = terrain.data.get_height(Vector3(world_x, 0.0, world_z))
		if not is_nan(h):
			return h
	if terrain is Terrain3DWorld:
		var th := (terrain as Terrain3DWorld).get_surface_height_at_world(world_x, world_z)
		if not is_nan(th):
			return th
	if is_nan(fallback_y):
		return NAN
	return fallback_y


static func snap_node_to_ground(node: Node3D, y_offset: float = 0.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	_deferred_snap(node, y_offset, TERRAIN_READY_FRAMES, false)


static func snap_node_to_ground_async(node: Node3D, y_offset: float = 0.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	await when_terrain_ready(node)
	_apply_snap(node, y_offset, false)


static func snap_node_bottom_to_ground_async(node: Node3D, clearance: float = 0.02) -> void:
	if node == null or not node.is_inside_tree():
		return
	await when_terrain_ready(node)
	_apply_snap(node, clearance, true)


static func snap_rigid_body_to_ground_async(body: RigidBody3D, clearance: float = 0.04) -> void:
	if body == null or not body.is_inside_tree():
		return
	body.freeze = true
	body.gravity_scale = 0.0
	await when_terrain_ready(body)
	var p := body.global_position
	await until_physics_ground_at(body, p.x, p.z, 80)
	var ground := get_ground_y(body, p.x, p.z, p.y)
	if not is_nan(ground):
		var lowest := _snap_bottom_reference_y(body)
		p.y += ground + clearance - lowest
		body.global_position = p
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = true
	var tree := body.get_tree()
	if tree:
		await tree.physics_frame
		await tree.physics_frame
	body.gravity_scale = 0.0
	body.freeze = true


## Не даёт RigidBody провалиться под Terrain3D (вызывать каждый кадр пока падает).
static func clamp_rigid_body_to_terrain(body: RigidBody3D, clearance: float = 0.04) -> void:
	if body == null or not body.is_inside_tree():
		return
	var ground := get_ground_y(body, body.global_position.x, body.global_position.z, NAN)
	if is_nan(ground):
		return
	var lowest_y := _snap_bottom_reference_y(body)
	var floor_y := ground + clearance
	if lowest_y >= floor_y:
		return
	body.global_position.y += floor_y - lowest_y
	var vel := body.linear_velocity
	if vel.y < 0.0:
		vel.y = 0.0
	body.linear_velocity = vel


static func until_physics_ground_at(
	from_node: Node, world_x: float, world_z: float, max_attempts: int = 60
) -> void:
	var tree := from_node.get_tree() if from_node else null
	if tree == null:
		return
	for _i in max_attempts:
		var ray_y := _raycast_ground_y(from_node, world_x, world_z, NAN)
		if not is_nan(ray_y):
			return
		await tree.physics_frame


static func snap_node_bottom_to_ground(node: Node3D, clearance: float = 0.02) -> void:
	if node == null or not node.is_inside_tree():
		return
	_deferred_snap(node, clearance, TERRAIN_READY_FRAMES, true)


static func _deferred_snap(node: Node3D, offset: float, frames_left: int, use_bottom: bool) -> void:
	var tree := node.get_tree()
	if tree == null or not is_instance_valid(node):
		return
	if frames_left > 0:
		tree.process_frame.connect(
			func() -> void: _deferred_snap(node, offset, frames_left - 1, use_bottom),
			CONNECT_ONE_SHOT
		)
		return
	_apply_snap(node, offset, use_bottom)


static func _apply_snap(node: Node3D, offset: float, use_bottom: bool) -> void:
	if not is_instance_valid(node):
		return
	var p := node.global_position
	var ground := get_ground_y(node, p.x, p.z, p.y)
	if is_nan(ground):
		return
	if use_bottom:
		var lowest := _snap_bottom_reference_y(node)
		node.global_position.y += ground + offset - lowest
	else:
		p.y = ground + offset
		node.global_position = p


static func _lowest_global_y(node: Node3D) -> float:
	var lowest := node.global_position.y
	for mi: MeshInstance3D in _collect_mesh_instances(node):
		if mi.mesh == null:
			continue
		var aabb := mi.mesh.get_aabb()
		var corners: Array[Vector3] = [
			aabb.position,
			aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
			aabb.position + Vector3(0.0, aabb.size.y, 0.0),
			aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
			aabb.position + Vector3(0.0, 0.0, aabb.size.z),
			aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
			aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
			aabb.end,
		]
		for c: Vector3 in corners:
			var global_corner: Vector3 = mi.global_transform * c
			lowest = minf(lowest, global_corner.y)
	return lowest


static func _lowest_collision_global_y(node: Node3D) -> float:
	var lowest := INF
	for cs: CollisionShape3D in _collect_collision_shapes(node):
		if cs.disabled or cs.shape == null:
			continue
		var aabb := _shape_local_aabb(cs.shape)
		var xf := cs.global_transform
		lowest = minf(lowest, (xf * aabb.position).y)
		lowest = minf(lowest, (xf * aabb.end).y)
	if lowest == INF:
		return node.global_position.y
	return lowest


static func _snap_bottom_reference_y(node: Node3D) -> float:
	if _has_collision_shapes(node):
		return _lowest_collision_global_y(node)
	return _lowest_global_y(node)


static func _has_collision_shapes(node: Node) -> bool:
	for cs: CollisionShape3D in _collect_collision_shapes(node):
		if not cs.disabled and cs.shape != null:
			return true
	return false


static func _collect_collision_shapes(node: Node) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	if node is CollisionShape3D:
		out.append(node as CollisionShape3D)
	for child in node.get_children():
		out.append_array(_collect_collision_shapes(child))
	return out


static func _collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_collect_mesh_instances(child))
	return out


static func _collision_half_extent_y(body: RigidBody3D) -> float:
	var lowest := INF
	var highest := -INF
	for child in body.get_children():
		if child is CollisionShape3D:
			var cs := child as CollisionShape3D
			if cs.disabled or cs.shape == null:
				continue
			var aabb := _shape_local_aabb(cs.shape)
			var xf := cs.global_transform
			lowest = minf(lowest, (xf * aabb.position).y)
			highest = maxf(highest, (xf * aabb.end).y)
	if lowest == INF:
		return 0.14
	return maxf((highest - lowest) * 0.5, 0.06)


static func _shape_local_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var s := (shape as BoxShape3D).size
		return AABB(-s * 0.5, s)
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3.ONE * r * 2.0)
	return AABB(Vector3(-0.22, -0.08, -0.22), Vector3(0.44, 0.16, 0.44))


static func _raycast_ground_y(from_node: Node, world_x: float, world_z: float, fallback_y: float) -> float:
	var vp := from_node.get_viewport()
	if vp == null:
		return fallback_y
	var world := vp.get_world_3d()
	if world == null:
		return fallback_y
	var from := Vector3(world_x, RAY_UP, world_z)
	var to := Vector3(world_x, -RAY_DOWN, world_z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return fallback_y
	return hit.position.y
