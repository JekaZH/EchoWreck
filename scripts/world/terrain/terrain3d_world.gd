@tool
class_name Terrain3DWorld
extends Terrain3D
## 4 региона Terrain3D (2×2), центр мира в (0,0). Поляна + 4 тропинки.

@export_group("Assets")
@export var terrain_assets: Terrain3DAssets
## Выключено = лепите регионы и траву вручную в Terrain3D (рекомендуется).
@export var auto_generate_if_empty: bool = false
## В игре: если в storage нет сохранённых регионов — временный процедурный terrain (не провалиться).
@export var runtime_fallback_if_empty: bool = true
@export var regenerate_if_layout_outdated: bool = false
@export var layout_version: int = 5

@export_group("Регионы")
## Размер одного квадрата региона (м). Всего 2×2 = 4 региона.
@export var region_size_m: int = 128
@export var regions_per_side: int = 2
@export var heightmap_resolution: int = 128
@export_range(4.0, 40.0, 1.0) var height_scale: float = 13.0
@export var noise_seed: int = 4217
@export_range(4.0, 48.0, 1.0) var edge_blend_m: float = 16.0

@export_group("Сохранение")
## Пустая папка без файлов регионов даёт предупреждение — генерируем и сохраняем сами.
@export_dir var storage_directory: String = "res://terrain"
@export var save_generated_to_disk: bool = true

@export_group("Поляна и тропинки")
@export_range(8.0, 60.0, 1.0) var meadow_radius_m: float = 20.0
@export_range(2.0, 12.0, 0.5) var path_width_m: float = 5.5
@export_range(24.0, 100.0, 1.0) var path_length_m: float = 72.0
@export_range(0.0, 0.2, 0.01) var meadow_height: float = 0.045
@export_range(0.0, 0.2, 0.01) var path_height: float = 0.05

@export_group("Холмы")
@export_range(0.08, 0.35, 0.01) var hill_peak_height: float = 0.2
@export_range(20.0, 48.0, 1.0) var hill_radius_m: float = 32.0
@export var hill_centers_m: PackedVector2Array = [
	Vector2(42, 42), Vector2(-42, 42), Vector2(-42, -42), Vector2(42, -42),
]

@export_group("Декор")
## Только если включена процедурная генерация — иначе трава кистью Instancer в Terrain3D.
@export var auto_scatter_grass: bool = false
@export_range(0, 2000, 50) var grass_instance_count: int = 650

@export_group("Редактор")
@export var spawn_path_markers: bool = false
## Включите один раз для процедурного превью (затирает ручную лепку).
@export var editor_regenerate_now: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			call_deferred("_editor_regenerate")
		editor_regenerate_now = false

const PATH_NAMES: PackedStringArray = ["PathEast", "PathWest", "PathNorth", "PathSouth"]
const META_LAYOUT_VERSION := &"ew_terrain_layout_version"
const META_LAYOUT_READY := &"ew_terrain_layout_ready"
const VERSION_FILE_NAME := "layout_version.txt"
const TEX_GRASS := 1
const TEX_DIRT := 0

## Сетка 2×2 вокруг центра мира (индексы регионов Terrain3D).
const REGION_GRID: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(0, 0),
]

signal layout_ready

var _layout_ready_emitted := false


func _enter_tree() -> void:
	add_to_group("world_terrain")
	top_level = false
	global_position = Vector3.ZERO
	global_rotation = Vector3.ZERO
	_layout_ready_emitted = false
	set_meta(META_LAYOUT_READY, false)
	# Пустой data_directory в сцене даёт ошибку — выставляем только при валидных файлах.
	if not Engine.is_editor_hint():
		data_directory = ""


func _ready() -> void:
	_layout_ready_emitted = false
	set_meta(META_LAYOUT_READY, false)
	collision_layer = 1
	## Игрок (1), harvestable (16), dropped_item (32).
	collision_mask = 1 | 16 | 32
	_apply_assets()
	_configure_material()
	_ensure_storage_dir()
	_sanitize_storage_marker()

	var need_gen := false
	if regenerate_if_layout_outdated and _is_layout_outdated():
		_clear_all_regions()
		need_gen = true
	elif _is_empty():
		await _try_bind_storage()
		if _is_empty():
			if not Engine.is_editor_hint() and runtime_fallback_if_empty:
				need_gen = true
			else:
				need_gen = auto_generate_if_empty

	if need_gen:
		_clear_all_regions()
		_generate_startup_terrain()
		_save_storage()

	if spawn_path_markers:
		_ensure_path_markers()
	call_deferred("_finish_layout_startup")
	if not Engine.is_editor_hint() and auto_scatter_grass and auto_generate_if_empty:
		call_deferred("_scatter_grass")


func has_active_regions() -> bool:
	return not _is_empty()


func is_layout_ready() -> bool:
	return _layout_ready_emitted and has_active_regions()


func get_world_half_extent() -> float:
	return float(region_size_m * regions_per_side) * 0.5


func get_path_end_world_positions() -> Array[Vector3]:
	var half := get_world_half_extent()
	var end := minf(path_length_m, half - 8.0)
	return [
		global_position + Vector3(end, 0.0, 0.0),
		global_position + Vector3(-end, 0.0, 0.0),
		global_position + Vector3(0.0, 0.0, -end),
		global_position + Vector3(0.0, 0.0, end),
	]


func get_surface_height_at_world(world_x: float, world_z: float) -> float:
	if data == null:
		return global_position.y
	var h: float = data.get_height(Vector3(world_x, 0.0, world_z))
	if is_nan(h):
		return global_position.y
	return h


func _apply_assets() -> void:
	if terrain_assets == null:
		return
	# Копия без generated mesh — set_mesh_asset(null) ломает рендер и блокирует загрузку уровней.
	assets = _build_runtime_assets(terrain_assets)


func _mesh_asset_keep(ma: Terrain3DMeshAsset) -> bool:
	if ma == null:
		return false
	if ma.generated_type != 0:
		return false
	return ma.scene_file != null


func _build_runtime_assets(source: Terrain3DAssets) -> Terrain3DAssets:
	var runtime := Terrain3DAssets.new()
	for ti in source.get_texture_count():
		var tex: Terrain3DTextureAsset = source.get_texture(ti)
		if tex != null:
			runtime.set_texture(ti, tex)
	var mesh_i := 0
	for mi in source.get_mesh_count():
		var ma: Terrain3DMeshAsset = source.get_mesh_asset(mi)
		if not _mesh_asset_keep(ma):
			continue
		runtime.set_mesh_asset(mesh_i, ma.duplicate(true) as Terrain3DMeshAsset)
		mesh_i += 1
	return runtime


func _configure_material() -> void:
	if material == null:
		return
	material.auto_shader = true
	material.set_shader_param("auto_slope", 11.0)
	material.set_shader_param("blend_sharpness", 0.92)
	material.world_background = Terrain3DMaterial.NONE


func _is_empty() -> bool:
	if data == null:
		return true
	return data.get_regions_active().is_empty()


func _is_layout_outdated() -> bool:
	if int(get_meta(META_LAYOUT_VERSION, -1)) != layout_version:
		return true
	return not _storage_version_matches()


func _ensure_storage_dir() -> void:
	if storage_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(storage_directory)


func _storage_version_path() -> String:
	return storage_directory.path_join(VERSION_FILE_NAME)


func _storage_version_matches() -> bool:
	var path := _storage_version_path()
	if not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path).strip_edges()
	return text == str(layout_version)


func _storage_has_region_files() -> bool:
	if storage_directory.is_empty():
		return false
	var dir := DirAccess.open(storage_directory)
	if dir == null:
		return false
	var found := false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry != VERSION_FILE_NAME and entry != ".gitkeep":
			found = true
			break
		entry = dir.get_next()
	dir.list_dir_end()
	return found


func _sanitize_storage_marker() -> void:
	if storage_directory.is_empty():
		return
	if _storage_has_region_files():
		return
	var path := _storage_version_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _try_bind_storage() -> bool:
	if storage_directory.is_empty() or not save_generated_to_disk:
		return false
	if not _storage_has_region_files():
		return false
	if not _storage_version_matches():
		return false
	data_directory = ""
	data_directory = storage_directory
	await _defer_frames(3)
	return not _is_empty()


func _save_storage() -> void:
	if not save_generated_to_disk or storage_directory.is_empty() or data == null:
		return
	_ensure_storage_dir()
	data_directory = storage_directory
	data.save_directory(storage_directory)
	var vf := FileAccess.open(_storage_version_path(), FileAccess.WRITE)
	if vf:
		vf.store_string(str(layout_version))
		vf.close()


func _clear_all_regions() -> void:
	data_directory = ""
	if data == null:
		return
	for region: Terrain3DRegion in data.get_regions_active():
		data.remove_region(region, true)


func _editor_regenerate() -> void:
	_clear_all_regions()
	_layout_ready_emitted = false
	set_meta(META_LAYOUT_READY, false)
	_generate_startup_terrain()
	_save_storage()
	_ensure_path_markers()
	call_deferred("_finish_layout_startup")


func _generate_startup_terrain() -> void:
	region_size = region_size_m
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.frequency = 0.011
	var half_world := get_world_half_extent()

	for grid_pos: Vector2i in REGION_GRID:
		var images := _build_region_images(grid_pos, noise, half_world)
		var origin := Vector3(
			float(grid_pos.x) * float(region_size_m),
			0.0,
			float(grid_pos.y) * float(region_size_m)
		)
		data.import_images(images, origin, 0.0, height_scale)

	set_meta(META_LAYOUT_VERSION, layout_version)
	set_meta(META_LAYOUT_READY, false)
	_layout_ready_emitted = false


func _build_region_images(grid_pos: Vector2i, noise: FastNoiseLite, half_world: float) -> Array:
	var res := heightmap_resolution
	var height_img := Image.create_empty(res, res, false, Image.FORMAT_RF)
	var control_img := Image.create_empty(res, res, false, Image.FORMAT_RF)
	var origin_x := float(grid_pos.x) * float(region_size_m)
	var origin_z := float(grid_pos.y) * float(region_size_m)
	var meters_per_pixel := float(region_size_m) / float(res)

	for x in res:
		for z in res:
			var wx := origin_x + (float(x) + 0.5) * meters_per_pixel
			var wz := origin_z + (float(z) + 0.5) * meters_per_pixel
			var h := _paint_height(wx, wz, noise, half_world)
			height_img.set_pixel(x, z, Color(h, 0.0, 0.0, 1.0))
			control_img.set_pixel(x, z, Color(_paint_control(wx, wz, h), 0.0, 0.0, 1.0))

	return [height_img, control_img, null]


func _paint_height(wx: float, wz: float, noise: FastNoiseLite, half_world: float) -> float:
	var dist := Vector2(wx, wz).length()
	var path_dist := _distance_to_paths(wx, wz)
	var h := meadow_height

	if dist <= meadow_radius_m:
		h = meadow_height
	elif path_dist <= path_width_m * 0.5:
		var edge := smoothstep(path_width_m * 0.5, path_width_m * 0.22, path_dist)
		h = lerpf(meadow_height, path_height, edge)
	else:
		var hill := 0.0
		for center in hill_centers_m:
			var d := Vector2(wx, wz).distance_to(center)
			var t := 1.0 - smoothstep(hill_radius_m * 0.25, hill_radius_m, d)
			hill = maxf(hill, t * t * (3.0 - 2.0 * t))
		var roll := noise.get_noise_2d(wx, wz) * 0.04
		h = meadow_height + hill * hill_peak_height + roll
		var meadow_blend := smoothstep(meadow_radius_m, meadow_radius_m + 12.0, dist)
		h = lerpf(meadow_height, h, meadow_blend)
		if path_dist < path_width_m * 1.5:
			var path_blend := smoothstep(path_width_m * 1.5, path_width_m * 0.4, path_dist)
			h = lerpf(h, path_height, path_blend * 0.8)

	var edge_dist := half_world - maxf(absf(wx), absf(wz))
	if edge_dist < edge_blend_m:
		var rim := 1.0 - smoothstep(0.0, edge_blend_m, edge_dist)
		h = lerpf(h, hill_peak_height * 1.3, rim * 0.6)
	if edge_dist < 4.0:
		h = lerpf(0.0, h, edge_dist / 4.0)

	return clampf(h, 0.0, 1.0)


func _paint_control(wx: float, wz: float, height: float) -> float:
	var path_dist := _distance_to_paths(wx, wz)
	var dist := Vector2(wx, wz).length()
	if path_dist <= path_width_m * 0.55:
		return _encode_control(TEX_DIRT, TEX_DIRT, 0, false)
	if dist <= meadow_radius_m + 1.0:
		return _encode_control(TEX_GRASS, TEX_GRASS, 0, false)
	if height > meadow_height + hill_peak_height * 0.45:
		return _encode_control(TEX_GRASS, TEX_DIRT, 96, true)
	return _encode_control(TEX_GRASS, TEX_GRASS, 0, true)


func _encode_control(base_id: int, overlay_id: int, blend: int, autoshader: bool) -> float:
	var bits: int = 0
	bits |= (base_id & 0x1F) << 27
	bits |= (overlay_id & 0x1F) << 22
	bits |= (blend & 0xFF) << 14
	if autoshader:
		bits |= 1
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, bits)
	return bytes.decode_float(0)


func _distance_to_paths(wx: float, wz: float) -> float:
	var best := INF
	if wx >= -path_width_m * 0.5 and wx <= path_length_m:
		best = minf(best, absf(wz))
	if wx <= path_width_m * 0.5 and wx >= -path_length_m:
		best = minf(best, absf(wz))
	if wz >= -path_width_m * 0.5 and wz <= path_length_m:
		best = minf(best, absf(wx))
	if wz <= path_width_m * 0.5 and wz >= -path_length_m:
		best = minf(best, absf(wx))
	return best


func _finish_layout_startup() -> void:
	await _wait_physics_catchup()
	if _is_empty():
		push_error(
			"Terrain3DWorld: нет активных регионов. Сохраните terrain в %s "
			% storage_directory
			+ "или включите runtime_fallback_if_empty / Editor Regenerate Now."
		)
	elif not _layout_ready_emitted:
		_layout_ready_emitted = true
		set_meta(META_LAYOUT_READY, true)
	# Всегда сигналим — иначе bootstrap / переходы уровней зависают на экране загрузки.
	layout_ready.emit()


func _wait_physics_catchup() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for _i in 10:
		await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame
	if data != null:
		var h: float = data.get_height(global_position)
		if is_nan(h):
			push_warning("Terrain3DWorld: коллизия в центре (0,0) ещё не готова.")


func _defer_frames(count: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for _i in count:
		await tree.process_frame


func _ensure_path_markers() -> void:
	var root := get_node_or_null("PathPortals") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "PathPortals"
		add_child(root)
		if Engine.is_editor_hint() and is_inside_tree():
			root.owner = get_tree().edited_scene_root
	for c in root.get_children():
		c.queue_free()
	var ends := get_path_end_world_positions()
	for i in PATH_NAMES.size():
		var marker := Marker3D.new()
		marker.name = PATH_NAMES[i]
		root.add_child(marker)
		if Engine.is_editor_hint() and is_inside_tree():
			marker.owner = get_tree().edited_scene_root
		marker.global_position = ends[i]
		var gy := get_surface_height_at_world(ends[i].x, ends[i].z)
		if not is_nan(gy):
			marker.global_position.y = gy + 0.08


func _scatter_grass() -> void:
	if data == null:
		return
	if assets == null or assets.get_mesh_count() == 0:
		_ensure_grass_mesh_asset()
	if assets == null or assets.get_mesh_count() == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed + 99
	var half := get_world_half_extent() * 0.78
	if assets.get_mesh_count() == 0:
		return
	var per_mesh := maxi(grass_instance_count / assets.get_mesh_count(), 1)
	for mesh_i in assets.get_mesh_count():
		if assets.get_mesh_asset(mesh_i) == null:
			continue
		var xforms: Array[Transform3D] = []
		var placed := 0
		var attempts := 0
		while placed < per_mesh and attempts < per_mesh * 14:
			attempts += 1
			var wx := rng.randf_range(-half, half)
			var wz := rng.randf_range(-half, half)
			if Vector2(wx, wz).length() < meadow_radius_m + 1.5:
				continue
			if _distance_to_paths(wx, wz) < path_width_m * 0.7:
				continue
			var world_pos := global_position + Vector3(wx, 0.0, wz)
			var ground_y := data.get_height(world_pos)
			if is_nan(ground_y):
				continue
			var xf := Transform3D.IDENTITY
			xf.origin = Vector3(world_pos.x, ground_y, world_pos.z)
			xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
			xf = xf.scaled(Vector3.ONE * rng.randf_range(0.85, 1.15))
			xforms.append(xf)
			placed += 1
		if not xforms.is_empty():
			instancer.add_transforms(mesh_i, xforms)


const DEFAULT_GRASS_SCENE := "res://assets/stylized_nature_kit_standard/glTF/Grass_Common_Short.gltf"


func _ensure_grass_mesh_asset() -> void:
	if assets == null:
		assets = Terrain3DAssets.new()
	if assets.get_mesh_count() > 0:
		return
	var scene := load(DEFAULT_GRASS_SCENE) as PackedScene
	if scene == null:
		return
	var ma := Terrain3DMeshAsset.new()
	ma.name = "Grass"
	ma.set_scene_file(scene)
	ma.height_offset = 0.12
	assets.set_mesh_asset(0, ma)
