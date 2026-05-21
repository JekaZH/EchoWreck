class_name MeleeArcHit
extends RefCounted
## Поиск целей в дуге перед атакующим (для меча). Инструменты используют RayCast.

const DEFAULT_MASK := 16


static func collect_damage_targets(
	attacker: Node3D,
	origin: Vector3,
	forward: Vector3,
	reach: float,
	arc_radius: float,
	arc_angle_deg: float,
	sample_count: int = 7,
	collision_mask: int = DEFAULT_MASK
) -> Array[Node]:
	var result: Array[Node] = []
	if attacker == null or forward.length_squared() < 0.0001:
		return result
	forward = forward.normalized()
	var space := attacker.get_world_3d().direct_space_state
	if space == null:
		return result

	var half_angle := deg_to_rad(arc_angle_deg * 0.5)
	var seen: Dictionary = {}
	var samples := maxi(sample_count, 3)
	var exclude: Array[RID] = [attacker.get_rid()]

	for i in range(samples):
		var t := lerpf(-half_angle, half_angle, float(i) / float(samples - 1))
		var dir := forward.rotated(Vector3.UP, t)
		var center := origin + dir * reach * 0.55
		var shape := SphereShape3D.new()
		shape.radius = arc_radius
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.transform = Transform3D(Basis(), center)
		params.collision_mask = collision_mask
		params.collide_with_areas = false
		params.collide_with_bodies = true
		params.exclude = exclude
		for hit in space.intersect_shape(params, 16):
			var collider: Object = hit.get("collider")
			if collider == null:
				continue
			var target := _resolve_damage_target(collider as Node)
			if target == null:
				continue
			var id := target.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			result.append(target)
	return result


static func _resolve_damage_target(collider: Node) -> Node:
	if collider == null:
		return null
	if collider.has_method("take_damage"):
		return collider
	var parent := collider.get_parent()
	if parent != null and parent.has_method("take_damage"):
		return parent
	return null
