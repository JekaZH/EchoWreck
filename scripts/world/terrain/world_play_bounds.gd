extends Node3D
## Мягкая граница поляны: предупреждение у края + невидимая стена на самом краю terrain.

@export var terrain_path: NodePath = ^"../WorldTerrain"
@export_range(0.5, 8.0, 0.5) var wall_height_m: float = 3.0
@export var show_debug_wall: bool = false


func _ready() -> void:
	call_deferred("_build_when_ready")


func _build_when_ready() -> void:
	var terrain := _get_terrain()
	if terrain == null:
		push_warning("WorldPlayBounds: WorldTerrain не найден.")
		return
	await TerrainHeightQuery.when_terrain_ready(terrain)
	_build_edge_walls(terrain)


func _get_terrain() -> Terrain3DWorld:
	if terrain_path != NodePath():
		var n := get_node_or_null(terrain_path)
		if n is Terrain3DWorld:
			return n as Terrain3DWorld
	for n in get_tree().get_nodes_in_group("world_terrain"):
		if n is Terrain3DWorld:
			return n as Terrain3DWorld
	return null


func _build_edge_walls(terrain: Terrain3DWorld) -> void:
	var half := terrain.get_world_half_extent() - 1.0
	var y_top := terrain.get_surface_height_at_world(terrain.global_position.x, terrain.global_position.z) + wall_height_m
	var y_bot := y_top - wall_height_m * 2.0
	var thickness := 2.0
	var specs := [
		{"pos": Vector3(0, 0, half), "size": Vector3(half * 2.0 + 4.0, wall_height_m * 2.0, thickness)},
		{"pos": Vector3(0, 0, -half), "size": Vector3(half * 2.0 + 4.0, wall_height_m * 2.0, thickness)},
		{"pos": Vector3(half, 0, 0), "size": Vector3(thickness, wall_height_m * 2.0, half * 2.0 + 4.0)},
		{"pos": Vector3(-half, 0, 0), "size": Vector3(thickness, wall_height_m * 2.0, half * 2.0 + 4.0)},
	]
	for spec in specs:
		var body := StaticBody3D.new()
		body.name = "EdgeWall"
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		body.position = spec.pos
		body.position.y = (y_top + y_bot) * 0.5
		if show_debug_wall:
			var mesh_inst := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = spec.size
			mesh_inst.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1, 0.2, 0.2, 0.15)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_inst.material_override = mat
			body.add_child(mesh_inst)
