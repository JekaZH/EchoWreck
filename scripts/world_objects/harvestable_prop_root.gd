@tool
class_name HarvestablePropRoot
extends Node3D
## Дерево / камень / руда: модель вручную или по варианту, outline и коллизия — кнопками.

enum PropPreset {
	TREE,
	ROCK,
	CUSTOM,
}

enum CollisionFitMode {
	CYLINDER,
	SPHERE,
}

const OUTLINE_MATERIAL := preload("res://shaders/outline_material.tres")
const MODEL_TREE := "res://assets/stylized_nature_kit_standard/glTF/CommonTree_%d.gltf"
const MODEL_ROCK := "res://assets/stylized_nature_kit_standard/glTF/Rock_Medium_%d.gltf"
const EDITOR_GIZMO_PATH := NodePath("EditorPlacementGizmo")

@export_group("Модель")
@export var preset: PropPreset = PropPreset.TREE
@export_range(1, 5, 1) var prop_variant: int = 1
@export var model_scene: PackedScene
@export_file("*.gltf", "*.scn") var model_scene_path: String = ""
@export var visual_root_path: NodePath = ^"VisualRoot"
@export var outline_mesh_path: NodePath = ^"OutlineMesh"

@export_group("Коллизия и подсветка")
@export var auto_fit_collision: bool = true
@export var collision_fit_mode: CollisionFitMode = CollisionFitMode.CYLINDER
@export var collision_radius_scale: float = 0.12
@export var collision_height_scale: float = 0.65
@export var highlight_radius_scale: float = 0.85
@export var use_convex_collision_for_rocks: bool = true
@export_range(0.0, 0.2, 0.005) var collision_shape_margin: float = 0.04

@export_group("Прозрачность (деревья)")
@export var fade_when_occluding_player: bool = false
@export_range(0.05, 1.0, 0.01) var faded_alpha: float = 0.12
@export_range(1.0, 48.0, 0.5) var fade_speed: float = 22.0
@export_range(0.5, 4.0, 0.05) var occlusion_test_height: float = 1.2
@export_range(0.0, 3.0, 0.05) var occlusion_padding: float = 0.85
@export_range(0.0, 3.0, 0.05) var occlusion_trunk_padding: float = 1.1
@export_range(0.0, 2.0, 0.05) var occlusion_line_padding: float = 0.55
@export_range(1.5, 5.0, 0.1) var occlusion_near_trunk_scale: float = 3.2
@export_range(4, 24, 1) var occlusion_view_samples: int = 16
@export var hide_outline_when_faded: bool = true

@export_group("Гизмо в редакторе")
@export var show_editor_gizmo: bool = true
@export var editor_gizmo_color: Color = Color(0.2, 0.85, 0.35, 0.22)

@export_group("Редактор")
@export var auto_sync_when_visual_changes: bool = true
@export_tool_button("Подгрузить модель (model_scene или вариант)") var action_rebuild: Callable:
	get: return Callable(self, &"tool_rebuild_model")
@export_tool_button("Синхронизировать outline") var action_outline: Callable:
	get: return Callable(self, &"tool_sync_outline")
@export_tool_button("Подогнать коллизию") var action_collision: Callable:
	get: return Callable(self, &"tool_fit_collision")
@export_tool_button("Обновить гизмо") var action_gizmo: Callable:
	get: return Callable(self, &"tool_update_gizmo")
@export_tool_button("Всё сразу") var action_all: Callable:
	get: return Callable(self, &"tool_apply_all")

var _fade_alpha: float = 1.0
var _surface_cache: Array[Dictionary] = []
var _gizmo_material: StandardMaterial3D
var _editor_sync_queued: bool = false
var _outline_material: ShaderMaterial
var _outline_base_color: Color = Color(1.0, 1.0, 0.0, 1.0)
var _player_in_highlight_area: bool = false

signal visual_ready


func has_runtime_visual() -> bool:
	return not _get_visual_meshes().is_empty()


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_editor_sync_if_has_visual")
		return
	call_deferred("_game_setup")


func _game_setup() -> void:
	_hide_editor_gizmo_in_game()
	if _get_visual_meshes().is_empty():
		var scene := _resolve_spawn_scene()
		if scene != null:
			_spawn_scene_into_visual_root(scene)
		else:
			push_warning(
				"HarvestablePropRoot: нет модели у ", name,
				" — задай model_scene / prop_variant или сохрани модель в VisualRoot в сцене"
			)
	_after_visual_ready()


func _hide_editor_gizmo_in_game() -> void:
	var gizmo := _get_editor_gizmo()
	if gizmo:
		gizmo.visible = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if fade_when_occluding_player:
		_update_occlusion_fade(delta)


func _notification(what: int) -> void:
	if not Engine.is_editor_hint() or not auto_sync_when_visual_changes:
		return
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		_queue_editor_sync()


func _queue_editor_sync() -> void:
	if _editor_sync_queued:
		return
	_editor_sync_queued = true
	call_deferred("_editor_sync_if_has_visual")


func _editor_sync_if_has_visual() -> void:
	_editor_sync_queued = false
	if _get_visual_meshes().is_empty():
		return
	tool_sync_outline()
	if auto_fit_collision:
		tool_fit_collision()
	tool_update_gizmo()


func tool_rebuild_model() -> void:
	var scene := _resolve_spawn_scene()
	if scene == null:
		push_warning("HarvestablePropRoot: укажи model_scene / model_scene_path или preset + prop_variant")
		return
	_spawn_scene_into_visual_root(scene)


func tool_sync_outline() -> void:
	_sync_outline_mesh()


func tool_fit_collision() -> void:
	if auto_fit_collision:
		_fit_collision_shapes()


func tool_update_gizmo() -> void:
	_update_editor_gizmo()


func tool_apply_all() -> void:
	if _resolve_spawn_scene() != null:
		tool_rebuild_model()
	else:
		tool_sync_outline()
	tool_fit_collision()
	tool_update_gizmo()


func _after_visual_ready() -> void:
	if _get_visual_meshes().is_empty():
		return
	_sync_outline_mesh()
	if auto_fit_collision:
		_fit_collision_shapes()
	if fade_when_occluding_player:
		_build_surface_cache()
	visual_ready.emit()


func _resolve_spawn_scene() -> PackedScene:
	if model_scene != null:
		return model_scene
	if not model_scene_path.is_empty() and ResourceLoader.exists(model_scene_path):
		return load(model_scene_path) as PackedScene

	var template := ""
	var max_v := 1
	match preset:
		PropPreset.TREE:
			template = MODEL_TREE
			max_v = 5
		PropPreset.ROCK:
			template = MODEL_ROCK
			max_v = 3
		_:
			return null

	var variant := clampi(prop_variant, 1, max_v)
	var path := template % variant
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


func _spawn_scene_into_visual_root(scene: PackedScene) -> void:
	var visual_root := get_node_or_null(visual_root_path) as Node3D
	if visual_root == null:
		push_warning("HarvestablePropRoot: нет VisualRoot")
		return

	for child in visual_root.get_children():
		child.queue_free()

	var inst := scene.instantiate()
	visual_root.add_child(inst)
	if Engine.is_editor_hint():
		var edited := get_tree().edited_scene_root
		if edited and inst is Node:
			_set_owner_recursive(inst, edited)
	if inst is Node3D:
		(inst as Node3D).position = Vector3.ZERO

	_surface_cache.clear()


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node == scene_root:
		return
	node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)


func _get_outline_material() -> ShaderMaterial:
	if _outline_material == null:
		_outline_material = OUTLINE_MATERIAL.duplicate() as ShaderMaterial
		var base: Variant = _outline_material.get_shader_parameter("outline_color")
		if base is Color:
			_outline_base_color = base
	return _outline_material


func _sync_outline_mesh() -> void:
	var outline := get_node_or_null(outline_mesh_path) as MeshInstance3D
	var visual := _find_primary_visual_mesh()
	if outline == null or visual == null or visual.mesh == null:
		return

	outline.mesh = visual.mesh
	outline.global_transform = visual.global_transform
	outline.visible = false
	outline.set_surface_override_material(0, _get_outline_material())
	_refresh_outline_display()


func _find_primary_visual_mesh() -> MeshInstance3D:
	var visual_root := get_node_or_null(visual_root_path)
	if visual_root == null:
		return null

	var best: MeshInstance3D = null
	var best_volume := -1.0
	for node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh == null:
			continue
		var aabb := mesh_inst.get_aabb()
		var volume := aabb.size.x * aabb.size.y * aabb.size.z
		if volume > best_volume:
			best_volume = volume
			best = mesh_inst
	return best


func _get_visual_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var visual_root := get_node_or_null(visual_root_path)
	if visual_root == null:
		return result
	for node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh != null:
			result.append(mesh_inst)
	return result


func _get_combined_local_aabb() -> AABB:
	var combined := AABB()
	var has_mesh := false
	for mesh_inst in _get_visual_meshes():
		var local_aabb := mesh_inst.get_aabb()
		var xf := global_transform.affine_inverse() * mesh_inst.global_transform
		var mesh_aabb := xf * local_aabb
		if not has_mesh:
			combined = mesh_aabb
			has_mesh = true
		else:
			combined = combined.merge(mesh_aabb)
	return combined


func _try_fit_convex_collision(body: StaticBody3D, col: CollisionShape3D) -> bool:
	var mesh_inst := _find_primary_visual_mesh()
	if mesh_inst == null or mesh_inst.mesh == null:
		return false

	var convex_shape := mesh_inst.mesh.create_convex_shape(true)
	if convex_shape == null:
		return false

	col.shape = convex_shape
	col.transform = body.global_transform.affine_inverse() * mesh_inst.global_transform
	col.shape.margin = collision_shape_margin
	return true


func _fit_sphere_collision(col: CollisionShape3D, aabb: AABB) -> void:
	var sphere := col.shape as SphereShape3D
	var half := aabb.size * 0.5
	var enclosing := half.length()
	var min_axis := maxf(maxf(half.x, half.y), half.z)
	var radius := maxf(enclosing, min_axis * 1.08) * collision_radius_scale
	radius = maxf(radius, min_axis)
	sphere.radius = radius
	col.position = aabb.get_center()
	col.shape.margin = collision_shape_margin


func _fit_collision_shapes() -> void:
	var aabb := _get_combined_local_aabb()
	if aabb.size == Vector3.ZERO:
		return

	var body := get_node_or_null("StaticBody3D") as StaticBody3D
	if body:
		var col := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null:
			var fitted := false
			if use_convex_collision_for_rocks and preset == PropPreset.ROCK:
				fitted = _try_fit_convex_collision(body, col)

			if not fitted and collision_fit_mode == CollisionFitMode.CYLINDER and col.shape is CylinderShape3D:
				var cylinder := col.shape as CylinderShape3D
				cylinder.height = maxf(0.5, aabb.size.y * collision_height_scale)
				cylinder.radius = maxf(0.2, maxf(aabb.size.x, aabb.size.z) * collision_radius_scale)
				col.position = Vector3(
					aabb.get_center().x,
					aabb.position.y + cylinder.height * 0.5,
					aabb.get_center().z
				)
				cylinder.margin = collision_shape_margin
				fitted = true
			elif not fitted and collision_fit_mode == CollisionFitMode.SPHERE and col.shape is SphereShape3D:
				_fit_sphere_collision(col, aabb)
				fitted = true

			if not fitted:
				push_warning("HarvestablePropRoot: не удалось подогнать коллизию у ", name)

	var highlight := get_node_or_null("HighlightArea/CollisionShape3D") as CollisionShape3D
	if highlight != null and highlight.shape is SphereShape3D:
		var highlight_sphere := highlight.shape as SphereShape3D
		highlight_sphere.radius = maxf(aabb.size.length() * highlight_radius_scale * 0.35, 1.5)
		highlight.position = Vector3(0.0, aabb.position.y + aabb.size.y * 0.45, 0.0)


func get_health_bar_height() -> float:
	var aabb := _get_combined_local_aabb()
	if aabb.size == Vector3.ZERO:
		return 2.0
	return aabb.position.y + aabb.size.y + 0.4


func _get_editor_gizmo() -> MeshInstance3D:
	return get_node_or_null(EDITOR_GIZMO_PATH) as MeshInstance3D


func _get_gizmo_material() -> StandardMaterial3D:
	if _gizmo_material == null:
		_gizmo_material = StandardMaterial3D.new()
		_gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_gizmo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_gizmo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_gizmo_material.no_depth_test = true
	_gizmo_material.albedo_color = editor_gizmo_color
	return _gizmo_material


func _update_editor_gizmo() -> void:
	var gizmo := _get_editor_gizmo()
	if gizmo == null:
		return

	if not Engine.is_editor_hint() or not show_editor_gizmo:
		gizmo.visible = false
		return

	var aabb := _get_combined_local_aabb()
	if aabb.size == Vector3.ZERO:
		gizmo.visible = false
		return

	var cyl := gizmo.mesh as CylinderMesh
	if cyl == null:
		cyl = CylinderMesh.new()
		gizmo.mesh = cyl

	var radius := maxf(aabb.size.x, aabb.size.z) * 0.5
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = maxf(aabb.size.y, 0.2)
	gizmo.position = Vector3(
		aabb.get_center().x,
		aabb.position.y + cyl.height * 0.5,
		aabb.get_center().z
	)
	gizmo.material_override = _get_gizmo_material()
	gizmo.visible = true


func _get_combined_world_aabb() -> AABB:
	var combined := AABB()
	var has_mesh := false
	for mesh_inst in _get_visual_meshes():
		var world_aabb := mesh_inst.global_transform * mesh_inst.get_aabb()
		if not has_mesh:
			combined = world_aabb
			has_mesh = true
		else:
			combined = combined.merge(world_aabb)
	return combined


func _prepare_fade_material(source: Material) -> Material:
	var fade_mat := source.duplicate()
	if fade_mat is StandardMaterial3D:
		var std := fade_mat as StandardMaterial3D
		std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
		std.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		std.cull_mode = BaseMaterial3D.CULL_DISABLED
		std.alpha_scissor_threshold = 0.0
	elif fade_mat is ORMMaterial3D:
		var orm := fade_mat as ORMMaterial3D
		orm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		orm.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
		orm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		orm.cull_mode = BaseMaterial3D.CULL_DISABLED
		orm.alpha_scissor_threshold = 0.0
	elif fade_mat is BaseMaterial3D:
		var base := fade_mat as BaseMaterial3D
		base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		base.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return fade_mat


func _build_surface_cache() -> void:
	_surface_cache.clear()
	for mesh_inst in _get_visual_meshes():
		var surf_count := mesh_inst.mesh.get_surface_count()
		for surface_idx in surf_count:
			var source_mat := mesh_inst.get_surface_override_material(surface_idx)
			if source_mat == null:
				source_mat = mesh_inst.mesh.surface_get_material(surface_idx)
			if source_mat == null:
				continue
			var fade_mat := _prepare_fade_material(source_mat)
			var base_alpha := 1.0
			if source_mat is BaseMaterial3D:
				base_alpha = (source_mat as BaseMaterial3D).albedo_color.a
			_surface_cache.append({
				"mesh": mesh_inst,
				"surface": surface_idx,
				"fade": fade_mat,
				"base_alpha": base_alpha,
				"cast_shadow": mesh_inst.cast_shadow,
			})


func _update_occlusion_fade(delta: float) -> void:
	if _surface_cache.is_empty():
		_build_surface_cache()
	if _surface_cache.is_empty():
		return

	var should_fade := _is_occluding_player()
	var target_alpha := faded_alpha if should_fade else 1.0
	var blend := fade_speed * (2.5 if should_fade else 1.0)
	_fade_alpha = lerpf(_fade_alpha, target_alpha, clampf(delta * blend, 0.0, 1.0))
	if should_fade and _fade_alpha > target_alpha + 0.08:
		_fade_alpha = maxf(target_alpha, _fade_alpha - delta * blend * 0.35)
	_apply_fade_alpha(_fade_alpha)


func _get_trunk_radius() -> float:
	var col := _get_trunk_collision_shape()
	if col != null and col.shape is CylinderShape3D:
		return (col.shape as CylinderShape3D).radius
	var world_aabb := _get_combined_world_aabb()
	if world_aabb.size.length_squared() < 0.0001:
		return 0.55
	return maxf(world_aabb.size.x, world_aabb.size.z) * 0.2


func _get_occlusion_bounds() -> Dictionary:
	var world_aabb := _get_combined_world_aabb()
	if world_aabb.size.length_squared() < 0.0001:
		return {}
	world_aabb = world_aabb.grow(occlusion_padding)
	var trunk_r := _get_trunk_radius()
	var line_radius := trunk_r + occlusion_line_padding
	var near_radius := trunk_r * occlusion_near_trunk_scale
	near_radius = minf(near_radius, maxf(world_aabb.size.x, world_aabb.size.z) * 0.42)
	return {
		"aabb": world_aabb,
		"center": world_aabb.get_center(),
		"line_radius": line_radius,
		"near_radius": near_radius,
	}


func _tree_between_cam_and_target(
		cam: Camera3D,
		target_pos: Vector3,
		tree_pos: Vector3,
		lateral_limit: float
	) -> bool:
	var view_dir := (-cam.global_transform.basis.z).normalized()
	var cam_pos := cam.global_position
	var rel_tree := tree_pos - cam_pos
	var rel_target := target_pos - cam_pos
	var tree_depth := rel_tree.dot(view_dir)
	var target_depth := rel_target.dot(view_dir)
	if tree_depth <= 0.08 or tree_depth >= target_depth - 0.12:
		return false
	var lateral := rel_tree - view_dir * tree_depth
	return lateral.length() <= lateral_limit


func _is_occluding_player() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var cam := get_viewport().get_camera_3d()
	if player == null or cam == null:
		return false

	var bounds := _get_occlusion_bounds()
	if bounds.is_empty():
		return false

	var cam_pos := cam.global_position
	var player_pos := player.global_position
	var chest_pos := player_pos + Vector3(0.0, occlusion_test_height, 0.0)
	var feet_pos := player_pos + Vector3(0.0, 0.35, 0.0)
	var world_aabb: AABB = bounds["aabb"]
	var tree_center: Vector3 = bounds["center"]
	var line_r: float = bounds["line_radius"]
	var near_r: float = bounds["near_radius"]

	# Внутри объёма этого дерева.
	if world_aabb.has_point(player_pos) or world_aabb.has_point(chest_pos) or world_aabb.has_point(feet_pos):
		return true

	# Между камерой и игроком по глубине и не сбоку (узкий коридор по стволу).
	var corridor_r := line_r * 1.2
	var between_player := _tree_between_cam_and_target(cam, player_pos, tree_center, corridor_r)
	var between_chest := _tree_between_cam_and_target(cam, chest_pos, tree_center, corridor_r)
	if not between_player and not between_chest:
		return false

	var tree_xz := Vector2(tree_center.x, tree_center.z)
	var player_xz := Vector2(player_pos.x, player_pos.z)
	if between_player and tree_xz.distance_to(player_xz) <= near_r:
		return true

	if between_player and _blocks_view_on_xz(cam_pos, player_pos, line_r, tree_center):
		return true
	if between_chest and _blocks_view_on_xz(cam_pos, chest_pos, line_r, tree_center):
		return true

	if between_player and _blocks_view_in_camera_space(cam, player_pos, line_r, tree_center):
		return true
	if between_chest and _blocks_view_in_camera_space(cam, chest_pos, line_r, tree_center):
		return true

	var height_offsets: Array = [0.35, 0.9, 1.35, 1.9, 2.6]
	for y_off in height_offsets:
		var sample_target := player_pos + Vector3(0.0, y_off, 0.0)
		if not _tree_between_cam_and_target(cam, sample_target, tree_center, corridor_r):
			continue
		if _segment_intersects_aabb(cam_pos, sample_target, world_aabb):
			return true
		if _view_segment_blocked_by_trunk(cam_pos, sample_target):
			return true

	return false


func _blocks_view_on_xz(cam_pos: Vector3, target_pos: Vector3, radius: float, tree_pos: Vector3) -> bool:
	var cam_xz := Vector2(cam_pos.x, cam_pos.z)
	var target_xz := Vector2(target_pos.x, target_pos.z)
	var tree_xz := Vector2(tree_pos.x, tree_pos.z)
	var seg := target_xz - cam_xz
	var seg_len_sq := seg.length_squared()
	if seg_len_sq < 0.01:
		return cam_xz.distance_to(tree_xz) <= radius
	var seg_len := sqrt(seg_len_sq)
	var seg_dir := seg / seg_len
	var along := (tree_xz - cam_xz).dot(seg_dir)
	if along < -0.15 or along > seg_len + 0.2:
		return false
	var closest := cam_xz + seg_dir * along
	return tree_xz.distance_to(closest) <= radius


func _blocks_view_in_camera_space(
		cam: Camera3D,
		target_pos: Vector3,
		lateral_limit: float,
		tree_pos: Vector3
	) -> bool:
	var cam_pos := cam.global_position
	var view_dir := (-cam.global_transform.basis.z).normalized()
	var rel_tree := tree_pos - cam_pos
	var rel_target := target_pos - cam_pos
	var tree_depth := rel_tree.dot(view_dir)
	var target_depth := rel_target.dot(view_dir)
	if tree_depth <= 0.05 or tree_depth >= target_depth + 0.5:
		return false
	var lateral := rel_tree - view_dir * tree_depth
	return lateral.length() <= lateral_limit


func _segment_intersects_aabb(from: Vector3, to: Vector3, box: AABB) -> bool:
	var dir := to - from
	var t_min := 0.0
	var t_max := 1.0
	for axis in 3:
		var box_min := box.position[axis]
		var box_max := box.position[axis] + box.size[axis]
		if absf(dir[axis]) < 0.00001:
			if from[axis] < box_min or from[axis] > box_max:
				return false
			continue
		var inv_d := 1.0 / dir[axis]
		var t0 := (box_min - from[axis]) * inv_d
		var t1 := (box_max - from[axis]) * inv_d
		if inv_d < 0.0:
			var swap := t0
			t0 = t1
			t1 = swap
		t_min = maxf(t_min, t0)
		t_max = minf(t_max, t1)
		if t_min > t_max:
			return false
	return t_min <= 1.0 and t_max >= 0.0


func _get_trunk_collision_shape() -> CollisionShape3D:
	var body := get_node_or_null("StaticBody3D") as StaticBody3D
	if body == null:
		return null
	return body.get_node_or_null("CollisionShape3D") as CollisionShape3D


func _view_segment_blocked_by_trunk(cam_pos: Vector3, target_pos: Vector3) -> bool:
	if collision_fit_mode != CollisionFitMode.CYLINDER:
		return false

	var col := _get_trunk_collision_shape()
	if col == null or not col.shape is CylinderShape3D:
		return false

	var cyl := col.shape as CylinderShape3D
	var xf := col.global_transform
	var axis := xf.basis.y.normalized()
	if axis.length_squared() < 0.0001:
		axis = Vector3.UP
	var center := xf.origin
	var half_h := cyl.height * 0.5
	var cap_a := center - axis * half_h
	var cap_b := center + axis * half_h
	var radius := cyl.radius + occlusion_trunk_padding

	var view := target_pos - cam_pos
	var view_len := view.length()
	if view_len < 0.05:
		return false

	var sample_count := maxi(occlusion_view_samples, 4)
	for i in sample_count:
		var t := float(i + 1) / float(sample_count + 1)
		var sample := cam_pos + view * t
		var closest := _closest_point_on_segment(sample, cap_a, cap_b)
		if sample.distance_to(closest) <= radius:
			return true
	return false


func _closest_point_on_segment(point: Vector3, seg_a: Vector3, seg_b: Vector3) -> Vector3:
	var ab := seg_b - seg_a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq < 0.00001:
		return seg_a
	var t := (point - seg_a).dot(ab) / ab_len_sq
	t = clampf(t, 0.0, 1.0)
	return seg_a + ab * t


func set_harvest_highlight(active: bool) -> void:
	_player_in_highlight_area = active
	_refresh_outline_display()


func _refresh_outline_display() -> void:
	var outline := get_node_or_null(outline_mesh_path) as MeshInstance3D
	if outline == null:
		return

	var is_faded := fade_when_occluding_player and _fade_alpha < 0.88
	var show_outline := _player_in_highlight_area
	if hide_outline_when_faded and is_faded:
		show_outline = false

	outline.visible = show_outline
	if show_outline:
		var mat := _get_outline_material()
		outline.set_surface_override_material(0, mat)
		mat.set_shader_parameter("outline_color", _outline_base_color)


func _apply_fade_alpha(alpha: float) -> void:
	var is_faded := alpha < 0.95
	for entry in _surface_cache:
		var mesh_inst: MeshInstance3D = entry["mesh"]
		var surface_idx: int = entry["surface"]
		var fade_mat: Material = entry["fade"]
		var base_alpha: float = entry["base_alpha"]
		var shadow_mode: int = entry["cast_shadow"]

		if not is_faded:
			mesh_inst.set_surface_override_material(surface_idx, null)
			mesh_inst.cast_shadow = shadow_mode
			continue

		var final_alpha := alpha * base_alpha
		if fade_mat is BaseMaterial3D:
			(fade_mat as BaseMaterial3D).albedo_color.a = final_alpha
		mesh_inst.set_surface_override_material(surface_idx, fade_mat)
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_refresh_outline_display()
