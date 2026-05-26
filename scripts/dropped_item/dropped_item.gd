# dropped_item.gd
class_name DroppedItem
extends RigidBody3D

const DEFAULT_DROP_SCENE := preload("res://scenes/world_objects/dropped_item/dropped_item.tscn")
const OUTLINE_MATERIAL := preload("res://shaders/outline_material.tres")
const LOOT_BEAM_VFX_SCRIPT := preload("res://scripts/dropped_item/dropped_item_loot_beam_vfx.gd")
const LOOT_BEAM_SETTINGS_SCRIPT := preload("res://scripts/dropped_item/dropped_item_loot_beam_settings.gd")
const DEFAULT_LOOT_BEAM_SETTINGS := preload("res://resources/dropped_item/default_loot_beam_settings.tres")
## Слой 6 — игрок (mask 1|16) через них проходит.
const LAYER_DROPPED: int = 32
const MASK_WORLD_AND_DROPPED: int = 33
const SETTLE_TIMEOUT_MS := 8000

@export var item_data: ItemData
@export var count: int = 1
@export_range(0.1, 10.0, 0.1) var mass_kg: float = 0.8
@export var lock_item_rotation: bool = true
@export_flags_3d_physics var body_collision_layer: int = LAYER_DROPPED
@export_flags_3d_physics var body_collision_mask: int = MASK_WORLD_AND_DROPPED
@export_range(0.0, 0.2, 0.005) var terrain_clearance_m: float = 0.05
## Столб, частицы, outline. Пусто — default_loot_beam_settings.tres.
@export var loot_beam_settings: Resource

@onready var bag_mesh: MeshInstance3D = $Bag
@onready var bag_collision: CollisionShape3D = $Bag/CollisionShape3D
@onready var fallback_collision: CollisionShape3D = $CollisionShape3D
@onready var pickup_area: Area3D = $PickupArea
@onready var label: Label3D = $Label3D

var _outline_mesh: MeshInstance3D
var _loot_beam_vfx: Node3D
var _outline_material: ShaderMaterial
var _settled: bool = false
var _settling: bool = false


func _ready() -> void:
	add_to_group("dropped_items")
	mass = mass_kg
	lock_rotation = lock_item_rotation
	collision_layer = body_collision_layer
	collision_mask = body_collision_mask
	linear_damp = 0.15
	angular_damp = 0.8
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = true
	_ensure_fallback_collision()
	_apply_item_visual()
	_build_collision_from_mesh()
	_setup_loot_visuals()
	_refresh_prompt_label()
	if label:
		label.visible = false
	if not body_entered.is_connected(_on_physics_contact):
		body_entered.connect(_on_physics_contact)
	if not DroppedItemHighlight.outlines_enabled_changed.is_connected(_on_global_outlines_changed):
		DroppedItemHighlight.outlines_enabled_changed.connect(_on_global_outlines_changed)
	call_deferred("_begin_physics")


func _begin_physics() -> void:
	if _settled or _settling:
		return
	await _settle_on_ground()


func ensure_settled() -> void:
	if _settled:
		return
	await _settle_on_ground()


func _settle_on_ground() -> void:
	if _settling:
		while _settling and is_inside_tree():
			await get_tree().process_frame
		return
	if _settled:
		return
	_settling = true
	await TerrainHeightQuery.when_terrain_ready(self)
	await TerrainHeightQuery.until_physics_ground_at(
		self, global_position.x, global_position.z, 120
	)
	freeze = false
	gravity_scale = 1.0
	sleeping = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	var deadline_ms := Time.get_ticks_msec() + SETTLE_TIMEOUT_MS
	var tree := get_tree()
	if tree:
		while Time.get_ticks_msec() < deadline_ms and _settling and not _settled:
			await tree.physics_frame
			if _has_world_contact() and _is_resting():
				_freeze_settled()
	if not _settled:
		_freeze_settled()
	_settling = false


func _on_physics_contact(_body: Node) -> void:
	if not _settling or _settled:
		return
	call_deferred("_try_finish_settling")


func _try_finish_settling() -> void:
	if not _settling or _settled:
		return
	if _has_world_contact() and _is_resting():
		_freeze_settled()


func _has_world_contact() -> bool:
	for body in get_colliding_bodies():
		if body is CollisionObject3D and (body.collision_layer & 1) != 0:
			return true
	return false


func _is_resting() -> bool:
	if sleeping:
		return true
	return linear_velocity.length() < 0.12 and angular_velocity.length() < 0.18


func _freeze_settled() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = true
	freeze = true
	gravity_scale = 0.0
	_settled = true
	_settling = false


func _ensure_fallback_collision() -> void:
	if fallback_collision == null:
		return
	if fallback_collision.shape == null:
		var box := BoxShape3D.new()
		box.size = Vector3(0.45, 0.28, 0.45)
		fallback_collision.shape = box
	fallback_collision.disabled = false


func _apply_item_visual() -> void:
	if item_data == null or item_data.mesh_on_ground == null:
		return
	if item_data.mesh_on_ground == DEFAULT_DROP_SCENE:
		return
	var visual_root := item_data.mesh_on_ground.instantiate()
	if visual_root == null:
		return
	if visual_root is DroppedItem:
		visual_root.free()
		return
	for child in visual_root.get_children():
		if child is MeshInstance3D:
			var src := child as MeshInstance3D
			bag_mesh.mesh = src.mesh
			bag_mesh.material_override = src.material_override
			if src.transform != Transform3D.IDENTITY:
				bag_mesh.transform = src.transform
			break
	visual_root.free()
	_fit_collision_to_mesh()
	_sync_outline_mesh()
	_apply_loot_rarity_colors()


func refresh_loot_highlight() -> void:
	_refresh_loot_highlight_visibility()


func _get_loot_beam_settings() -> Resource:
	if loot_beam_settings != null:
		return loot_beam_settings
	if DEFAULT_LOOT_BEAM_SETTINGS != null:
		return DEFAULT_LOOT_BEAM_SETTINGS
	return LOOT_BEAM_SETTINGS_SCRIPT.get_default()


func _setup_loot_visuals() -> void:
	_outline_mesh = MeshInstance3D.new()
	_outline_mesh.name = "OutlineMesh"
	_outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline_mesh)
	var beam_cfg := _get_loot_beam_settings()
	_outline_material = OUTLINE_MATERIAL.duplicate() as ShaderMaterial
	_outline_material.set_shader_parameter("outline_width", beam_cfg.outline_width)

	_loot_beam_vfx = LOOT_BEAM_VFX_SCRIPT.new()
	_loot_beam_vfx.name = "LootBeamVfx"
	_loot_beam_vfx.configure(beam_cfg)
	_loot_beam_vfx.ensure_built()
	add_child(_loot_beam_vfx)

	_sync_outline_mesh()
	_apply_loot_rarity_colors()
	_refresh_loot_highlight_visibility()


func _on_global_outlines_changed(_enabled: bool) -> void:
	_refresh_loot_highlight_visibility()


func _refresh_loot_highlight_visibility() -> void:
	var show := DroppedItemHighlight.outlines_enabled
	if _outline_mesh != null:
		_outline_mesh.visible = show and bag_mesh != null and bag_mesh.mesh != null
	if _loot_beam_vfx != null:
		_loot_beam_vfx.set_highlight_visible(show)


func _sync_outline_mesh() -> void:
	if _outline_mesh == null or bag_mesh == null or bag_mesh.mesh == null:
		return
	_outline_mesh.mesh = bag_mesh.mesh
	_outline_mesh.transform = bag_mesh.transform
	_apply_outline_material()


func _apply_outline_material() -> void:
	if _outline_mesh == null or _outline_material == null or _outline_mesh.mesh == null:
		return
	if _outline_mesh.mesh.get_surface_count() < 1:
		return
	_outline_mesh.set_surface_override_material(0, _outline_material)


func _apply_loot_rarity_colors() -> void:
	var color := _get_rarity_color()
	if _outline_material != null:
		_outline_material.set_shader_parameter("outline_color", color)
	if _loot_beam_vfx != null:
		_loot_beam_vfx.set_rarity_color(color)


static func _get_rarity_color_for(item: ItemData) -> Color:
	if item == null:
		return Color(0.92, 0.92, 0.92, 1.0)
	match item.rarity:
		"Uncommon":
			return Color(0.35, 0.72, 1.0, 1.0)
		"Rare":
			return Color(1.0, 0.88, 0.2, 1.0)
		"Epic":
			return Color(0.78, 0.42, 1.0, 1.0)
		"Legendary":
			return Color(1.0, 0.55, 0.12, 1.0)
		_:
			return Color(0.92, 0.92, 0.95, 1.0)


func _get_rarity_color() -> Color:
	return _get_rarity_color_for(item_data)


func _fit_collision_to_mesh() -> void:
	if fallback_collision == null or bag_mesh == null or bag_mesh.mesh == null:
		return
	var aabb := bag_mesh.mesh.get_aabb()
	var scale := bag_mesh.transform.basis.get_scale()
	var size := Vector3(
		maxf(aabb.size.x * scale.x, 0.12),
		maxf(aabb.size.y * scale.y, 0.08),
		maxf(aabb.size.z * scale.z, 0.12),
	)
	var box := BoxShape3D.new()
	box.size = size
	fallback_collision.shape = box
	var center := bag_mesh.transform * aabb.get_center()
	fallback_collision.position = Vector3(center.x, aabb.position.y * scale.y + size.y * 0.5, center.z)


func _build_collision_from_mesh() -> void:
	if fallback_collision != null:
		fallback_collision.disabled = false
	if bag_collision != null:
		bag_collision.disabled = true


func apply_drop_impulse(look_dir: Vector3) -> void:
	_settled = false
	_settling = false
	freeze = false
	gravity_scale = 1.0
	sleeping = false
	var flat := Vector3(look_dir.x, 0.0, look_dir.z)
	if flat.length_squared() < 0.01:
		flat = -global_basis.z
	flat = flat.normalized()
	apply_central_impulse(flat * 2.5 + Vector3.UP * 0.6)
	await _settle_on_ground()


func apply_spawn_pop() -> void:
	_settled = false
	_settling = false
	freeze = false
	gravity_scale = 1.0
	sleeping = false
	apply_central_impulse(
		Vector3(randf_range(-0.25, 0.25), 0.35, randf_range(-0.25, 0.25))
	)
	await _settle_on_ground()


func stabilize_for_save_load() -> void:
	_settled = false
	_settling = false
	await _settle_on_ground()


func get_pickup_prompt_text() -> String:
	var item_name := "???"
	if item_data != null and not item_data.display_name.is_empty():
		item_name = item_data.display_name
	var amount := maxi(count, 1)
	return "E — подобрать [%s] x%d" % [item_name, amount]


func get_prompt_world_position() -> Vector3:
	if label != null:
		return label.global_position
	return global_position + Vector3(0.0, 1.2, 0.0)


func _refresh_prompt_label() -> void:
	if label == null:
		return
	label.text = get_pickup_prompt_text()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.nearby_dropped_items.append(self)
		_refresh_prompt_label()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.nearby_dropped_items.erase(self)


func pickup() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("Inventory"):
		print("Игрок или Inventory не найден!")
		return false
	var inv := player.get_node("Inventory") as Inventory
	var success := inv.add_item(item_data, count)
	if success:
		print("Подобрано и добавлено в инвентарь: ", item_data.display_name, " x", count)
		queue_free()
	else:
		print("Инвентарь полон!")
	return false
