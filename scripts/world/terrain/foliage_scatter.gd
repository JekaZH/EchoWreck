@tool
class_name FoliageScatter
extends Node3D
## Трава и мелкая растительность (MultiMesh) по поверхности EchoTerrain.

const GRASS_SCENES: Array[String] = [
	"res://assets/stylized_nature_kit_standard/glTF/Grass_Common_Short.gltf",
	"res://assets/stylized_nature_kit_standard/glTF/Grass_Common_Tall.gltf",
	"res://assets/stylized_nature_kit_standard/glTF/Grass_Wispy_Short.gltf",
	"res://assets/stylized_nature_kit_standard/glTF/Grass_Wispy_Tall.gltf",
]

@export var terrain_path: NodePath
@export_range(0, 8000, 50) var instance_count: int = 2200
@export var area_size: Vector2 = Vector2(110.0, 110.0)
@export var area_center: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var max_slope: float = 0.42
@export_range(4.0, 30.0, 0.5) var spawn_clear_radius: float = 14.0
@export var random_seed: int = 90210

@export_tool_button("Scatter Foliage", "Reload") var _scatter_btn: Callable = _editor_scatter


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	scatter()


func _editor_scatter() -> void:
	scatter()


func scatter() -> void:
	_clear_children()
	var terrain := _get_terrain()
	if terrain == null:
		push_warning("FoliageScatter: EchoTerrain не найден.")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var per_type := maxi(instance_count / GRASS_SCENES.size(), 1)
	for path in GRASS_SCENES:
		var mesh := _load_mesh_from_gltf(path)
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = per_type
		var node := MultiMeshInstance3D.new()
		node.name = mesh.resource_name if not mesh.resource_name.is_empty() else path.get_file().get_basename()
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else node.owner
		var placed := 0
		var attempts := 0
		while placed < per_type and attempts < per_type * 12:
			attempts += 1
			var local_x := rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5) + area_center.x
			var local_z := rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5) + area_center.y
			if Vector2(local_x, local_z).length() < spawn_clear_radius:
				continue
			var world_x := terrain.global_position.x + local_x
			var world_z := terrain.global_position.z + local_z
			var y := terrain.get_surface_height_at_world(world_x, world_z)
			var y_side := terrain.get_surface_height_at_world(world_x + 0.6, world_z)
			var slope := absf(y_side - y) / 0.6
			if slope > max_slope:
				continue
			var world_pos := Vector3(world_x, y + 0.02, world_z)
			var xf := Transform3D.IDENTITY
			xf.origin = terrain.to_local(world_pos)
			xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
			var s := rng.randf_range(0.85, 1.25)
			xf = xf.scaled(Vector3(s, s, s))
			mm.set_instance_transform(placed, xf)
			placed += 1
		mm.instance_count = placed


func _get_terrain() -> EchoTerrain:
	if terrain_path != NodePath():
		var n := get_node_or_null(terrain_path)
		if n is EchoTerrain:
			return n as EchoTerrain
	var p := get_parent()
	if p is EchoTerrain:
		return p as EchoTerrain
	return TerrainHeightQuery.find_terrain(self)


func _load_mesh_from_gltf(path: String) -> Mesh:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	var mesh: Mesh = null
	for c in inst.get_children():
		if c is MeshInstance3D:
			mesh = (c as MeshInstance3D).mesh
			break
	inst.free()
	return mesh


func _clear_children() -> void:
	for c in get_children():
		c.queue_free()
