@tool
class_name EchoTerrain
extends MeshInstance3D
## Процедурный ландшафт с heightmap-коллизией и splat-текстурами.
## В инспекторе: Rebuild Terrain. Splat можно править в paint_data.splatmap (Image).

const GRASS_TEX := preload("res://assets/stylized_nature_kit_standard/Textures/Grass.png")
const DIRT_TEX := preload("res://assets/stylized_nature_kit_standard/Textures/PathRocks_Diffuse.png")
const ROCK_TEX := preload("res://assets/stylized_nature_kit_standard/Textures/Rocks_Diffuse.png")
const TERRAIN_SHADER := preload("res://shaders/terrain/terrain_splat.gdshader")

@export_group("Размер")
@export var terrain_size: Vector2 = Vector2(120.0, 120.0)
@export_range(16, 256, 1) var grid_resolution: int = 128
@export_range(0.5, 24.0, 0.25) var max_height: float = 7.5

@export_group("Генерация")
@export var paint_data: TerrainPaintData
@export var noise_seed: int = 4217
@export_range(0.0, 1.0, 0.01) var noise_scale: float = 0.045
@export_range(0.0, 1.0, 0.01) var detail_scale: float = 0.11
@export_range(0.0, 1.0, 0.01) var detail_strength: float = 0.28
@export_range(4.0, 40.0, 0.5) var spawn_flat_radius: float = 18.0
@export_range(4.0, 40.0, 0.5) var spawn_flat_blend: float = 14.0

@export_group("Коллизия")
@export_flags_3d_physics var collision_layer: int = 1
@export var rebuild_collision: bool = true

@export_tool_button("Rebuild Terrain", "Reload") var _rebuild_btn: Callable = _editor_rebuild

var _heights: PackedFloat32Array = PackedFloat32Array()
var _grid_points: int = 0
var _noise: FastNoiseLite


func _ready() -> void:
	add_to_group("world_terrain")
	if _heights.is_empty():
		rebuild_terrain()
	elif not Engine.is_editor_hint():
		_ensure_collision_body()


func _editor_rebuild() -> void:
	rebuild_terrain()


func rebuild_terrain() -> void:
	_grid_points = grid_resolution + 1
	_init_noise()
	_build_or_load_heightmap()
	_build_or_load_splatmap()
	mesh = _build_mesh()
	_apply_material()
	_update_heights_cache()
	if not Engine.is_editor_hint() and rebuild_collision:
		_ensure_collision_body()
	elif Engine.is_editor_hint():
		_remove_collision_body()


func get_surface_height_at_world(world_x: float, world_z: float) -> float:
	var local := to_local(Vector3(world_x, 0.0, world_z))
	return global_position.y + sample_height_local(local.x, local.z)


func sample_height_local(local_x: float, local_z: float) -> float:
	if _heights.is_empty():
		return global_position.y
	var u := (local_x + terrain_size.x * 0.5) / terrain_size.x
	var v := (local_z + terrain_size.y * 0.5) / terrain_size.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return 0.0
	var gx := clampi(int(u * float(grid_resolution)), 0, grid_resolution)
	var gz := clampi(int(v * float(grid_resolution)), 0, grid_resolution)
	return _heights[gz * _grid_points + gx]


func _init_noise() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.frequency = 1.0


func _build_or_load_heightmap() -> void:
	if paint_data != null and paint_data.heightmap != null \
			and paint_data.heightmap.get_width() == _grid_points \
			and paint_data.heightmap.get_height() == _grid_points:
		return
	var img := Image.create(_grid_points, _grid_points, false, Image.FORMAT_RF)
	for gz in _grid_points:
		for gx in _grid_points:
			var local_x := _grid_to_local_x(gx)
			var local_z := _grid_to_local_z(gz)
			var h := _generate_height(local_x, local_z)
			img.set_pixel(gx, gz, Color(h / max_height, 0.0, 0.0, 1.0))
	if paint_data == null:
		paint_data = TerrainPaintData.new()
	paint_data.heightmap = img


func _build_or_load_splatmap() -> void:
	if paint_data != null and paint_data.splatmap != null \
			and paint_data.splatmap.get_width() == _grid_points \
			and paint_data.splatmap.get_height() == _grid_points:
		return
	var img := Image.create(_grid_points, _grid_points, false, Image.FORMAT_RGB8)
	for gz in _grid_points:
		for gx in _grid_points:
			var local_x := _grid_to_local_x(gx)
			var local_z := _grid_to_local_z(gz)
			var h := _generate_height(local_x, local_z)
			var slope := _estimate_slope(gx, gz)
			var dist := Vector2(local_x, local_z).length()
			var path_w := 1.0 - smoothstep(6.0, 10.0, absf(local_z - 8.0) - local_x * 0.15)
			path_w = clampf(path_w, 0.0, 1.0) * smoothstep(spawn_flat_radius, spawn_flat_radius + 8.0, dist)
			var grass_w := clampf(1.0 - h / max_height * 0.7 - slope * 0.9 - path_w * 0.85, 0.05, 1.0)
			var dirt_w := clampf(path_w + (1.0 - grass_w) * 0.25, 0.0, 1.0)
			var rock_w := clampf(slope * 1.1 + h / max_height * 0.35, 0.0, 1.0)
			var sum := grass_w + dirt_w + rock_w + 0.001
			img.set_pixel(gx, gz, Color(grass_w / sum, dirt_w / sum, rock_w / sum))
	if paint_data == null:
		paint_data = TerrainPaintData.new()
	paint_data.splatmap = img


func _generate_height(local_x: float, local_z: float) -> float:
	var n1 := _noise.get_noise_2d(local_x * noise_scale * 40.0, local_z * noise_scale * 40.0)
	var n2 := _noise.get_noise_2d(local_x * detail_scale * 40.0, local_z * detail_scale * 40.0)
	var h := (n1 * 0.72 + n2 * detail_strength) * max_height
	var dist := Vector2(local_x, local_z).length()
	var flat := 1.0 - smoothstep(spawn_flat_radius, spawn_flat_radius + spawn_flat_blend, dist)
	return h * (1.0 - flat * 0.92)


func _estimate_slope(gx: int, gz: int) -> float:
	var h := _read_heightmap_pixel(gx, gz) * max_height
	var hx := _read_heightmap_pixel(mini(gx + 1, grid_resolution), gz) * max_height
	var hz := _read_heightmap_pixel(gx, mini(gz + 1, grid_resolution)) * max_height
	var cell := terrain_size / float(grid_resolution)
	var slope_x := absf(hx - h) / maxf(cell.x, 0.01)
	var slope_z := absf(hz - h) / maxf(cell.y, 0.01)
	return clampf(sqrt(slope_x * slope_x + slope_z * slope_z), 0.0, 1.5) / 1.5


func _read_heightmap_pixel(gx: int, gz: int) -> float:
	if paint_data == null or paint_data.heightmap == null:
		return 0.0
	return paint_data.heightmap.get_pixel(gx, gz).r


func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normals := PackedVector3Array()
	normals.resize(_grid_points * _grid_points)
	for gz in _grid_points:
		for gx in _grid_points:
			normals[gz * _grid_points + gx] = _calculate_normal(gx, gz)
	for gz in grid_resolution:
		for gx in grid_resolution:
			var i00 := gz * _grid_points + gx
			var i10 := gz * _grid_points + (gx + 1)
			var i01 := (gz + 1) * _grid_points + gx
			var i11 := (gz + 1) * _grid_points + (gx + 1)
			_add_vertex(st, gx, gz, normals[i00])
			_add_vertex(st, gx + 1, gz, normals[i10])
			_add_vertex(st, gx, gz + 1, normals[i01])
			_add_vertex(st, gx + 1, gz, normals[i10])
			_add_vertex(st, gx + 1, gz + 1, normals[i11])
			_add_vertex(st, gx, gz + 1, normals[i01])
	return st.commit()


func _add_vertex(st: SurfaceTool, gx: int, gz: int, normal: Vector3) -> void:
	var local_x := _grid_to_local_x(gx)
	var local_z := _grid_to_local_z(gz)
	var h := _read_heightmap_pixel(gx, gz) * max_height
	st.set_normal(normal)
	st.set_uv(Vector2(float(gx) / float(grid_resolution), float(gz) / float(grid_resolution)))
	st.add_vertex(Vector3(local_x, h, local_z))


func _calculate_normal(gx: int, gz: int) -> Vector3:
	var h := _read_heightmap_pixel(gx, gz) * max_height
	var hx := _read_heightmap_pixel(mini(gx + 1, grid_resolution), gz) * max_height
	var hz := _read_heightmap_pixel(gx, mini(gz + 1, grid_resolution)) * max_height
	var cell := terrain_size / float(grid_resolution)
	return Vector3(h - hx, cell.x, 0.0).cross(Vector3(0.0, cell.y, h - hz)).normalized()


func _apply_material() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("grass_tex", GRASS_TEX)
	mat.set_shader_parameter("dirt_tex", DIRT_TEX)
	mat.set_shader_parameter("rock_tex", ROCK_TEX)
	if paint_data != null and paint_data.splatmap != null:
		var splat_tex := ImageTexture.create_from_image(paint_data.splatmap)
		mat.set_shader_parameter("splat_map", splat_tex)
	material_override = mat


func _update_heights_cache() -> void:
	_heights.resize(_grid_points * _grid_points)
	for gz in _grid_points:
		for gx in _grid_points:
			_heights[gz * _grid_points + gx] = _read_heightmap_pixel(gx, gz) * max_height


func _ensure_collision_body() -> void:
	_remove_collision_body()
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = collision_layer
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = _grid_points
	hm.map_depth = _grid_points
	var data := PackedFloat32Array()
	data.resize(_grid_points * _grid_points)
	for gz in _grid_points:
		for gx in _grid_points:
			data[gz * _grid_points + gx] = _read_heightmap_pixel(gx, gz) * max_height
	hm.map_data = data
	shape_node.shape = hm
	shape_node.position = Vector3(-terrain_size.x * 0.5, 0.0, -terrain_size.y * 0.5)
	var cell := terrain_size / float(grid_resolution)
	shape_node.scale = Vector3(cell.x, 1.0, cell.y)
	body.add_child(shape_node)
	add_child(body)


func _remove_collision_body() -> void:
	var old := get_node_or_null("TerrainCollision")
	if old:
		old.queue_free()


func _grid_to_local_x(gx: int) -> float:
	return (float(gx) / float(grid_resolution) - 0.5) * terrain_size.x


func _grid_to_local_z(gz: int) -> float:
	return (float(gz) / float(grid_resolution) - 0.5) * terrain_size.y
