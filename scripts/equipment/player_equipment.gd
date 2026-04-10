class_name PlayerEquipment
extends Node

@export var skeleton: Skeleton3D
@export var chest_bone_name: String = "Spine"
@export var chest_visual_offset: Vector3 = Vector3.ZERO
@export var chest_visual_rotation: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var chest_visual_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var base_body_mesh_path: NodePath = NodePath("../Armature/GeneralSkeleton/SuperHero_Male")
@export var auto_fit_chest_scale: bool = true
@export var auto_fit_chest_padding: float = 1.03 # small extra scale to avoid clipping

var equipped_items: Dictionary = {}
var equipped_visuals: Dictionary = {}
var visuals_root: Node3D = null
var equipped_visual_skeletons: Dictionary = {}
var equipped_visual_bone_maps: Dictionary = {}

const EQUIPMENT_SLOTS = ["Head", "Chest", "Legs", "Feet", "Hands", "Belt", "Ring", "Amulet"]

signal equipment_changed(slot: String, item: ItemData)

func _ready() -> void:
	if not skeleton:
		skeleton = get_parent().get_node_or_null("Armature/GeneralSkeleton")

	for slot in EQUIPMENT_SLOTS:
		equipped_items[slot] = null
		equipped_visuals[slot] = null
		equipped_visual_skeletons[slot] = null
		equipped_visual_bone_maps[slot] = null
	
	if skeleton:
		_setup_equipment_attachments()
	
	var player := get_parent()
	if player and player is Node:
		var existing := player.get_node_or_null("EquipmentVisuals")
		if existing and existing is Node3D:
			visuals_root = existing
		else:
			visuals_root = Node3D.new()
			visuals_root.name = "EquipmentVisuals"
			player.call_deferred("add_child", visuals_root)

	# NOTE: Skinned equipment requires the same rig (bone names/hierarchy) as `skeleton`.
	# The provided `Male_Peasant_Body.gltf` uses a different rig, so we attach it rigidly to chest bone.
	set_process(false)

func _setup_equipment_attachments() -> void:
	# Chest anchor (like tools, but for torso)
	var chest_attach = skeleton.get_node_or_null("ChestAttachment")
	if chest_attach == null:
		var bone_attachment := BoneAttachment3D.new()
		bone_attachment.name = "ChestAttachment"
		bone_attachment.bone_name = _pick_chest_bone_name()
		skeleton.add_child(bone_attachment)
		
		var pivot := Node3D.new()
		pivot.name = "ChestPivot"
		bone_attachment.add_child(pivot)

func _pick_chest_bone_name() -> String:
	if not skeleton:
		return chest_bone_name
	
	# If user-set bone exists, keep it.
	if chest_bone_name != "" and skeleton.find_bone(chest_bone_name) != -1:
		return chest_bone_name
	
	# Try common chest bones.
	var candidates := ["Chest", "UpperChest", "Spine2", "Spine1", "Spine"]
	for c in candidates:
		if skeleton.find_bone(c) != -1:
			return c
	
	return chest_bone_name


func equip_item(item: ItemData) -> bool:
	if not item or not item.is_equipment:
		return false
	
	var slot = item.equipment_slot
	if not equipped_items.has(slot):
		return false
	
	# 🔥 снимаем старый
	var old_item = unequip_slot(slot)
	
	equipped_items[slot] = item
	
	
	var player = get_tree().get_first_node_in_group("player")

	if player:
		var stats = player.player_equipment.get_all_stats()
		
		for s in stats:
			print(s, ":", stats[s])
	
	
	# 🔥 бонусы
	print("PlayerEquipment.equip_item: ", item.display_name, " → ", slot)
	apply_special_bonuses(item, true)
	_update_visual_for_slot(slot)
	_recompute_player_stats()
	_update_base_body_visibility()
	
	print("Экипировано:", item.display_name)
	equipment_changed.emit(slot, item)
	return true

func equip_from_inventory(from_inv: Inventory, from_idx: int) -> bool:
	if not from_inv:
		return false
	var stack := from_inv.get_slot(from_idx)
	if not stack or not stack.item or not stack.item.is_equipment:
		return false
	
	var item: ItemData = stack.item
	var slot: String = item.equipment_slot
	if not equipped_items.has(slot):
		return false
	
	var player = get_parent()
	
	# Capture currently equipped item BEFORE equipping the new one
	var previous: ItemData = equipped_items.get(slot, null)
	
	# Equip new item (this will unequip previous internally)
	var ok := equip_item(item)
	if not ok:
		return false
	
	# Remove 1 from source stack (equipment is always 1 item)
	if stack.count > 1:
		stack.count -= 1
		from_inv.changed.emit()
	else:
		from_inv.clear_slot(from_idx)
	
	# Return previous item to source inventory if possible, otherwise drop to ground
	if previous:
		if from_inv.can_fit_item(previous, 1):
			from_inv.add_item(previous, 1)
		else:
			if player and player.has_method("_on_item_dropped"):
				var angle: float = player.rotation.y
				var look_dir: Vector3 = Vector3(sin(angle), 0.0, cos(angle)).normalized()
				var spawn_pos: Vector3 = player.global_position + look_dir * 2.5 + Vector3(0.0, 0.8, 0.0)
				player._on_item_dropped(ItemStack.new(previous, 1), 1, spawn_pos, look_dir)
			else:
				# Fallback: try to put it back anyway (should rarely happen)
				from_inv.add_item(previous, 1)
	
	return true


func unequip_slot(slot: String) -> ItemData:
	if not equipped_items.has(slot):
		return null
	
	var old_item = equipped_items[slot]
	if not old_item:
		return null
	
	# 🔥 убираем бонусы
	if equipped_items[slot]:
		print("PlayerEquipment.unequip_slot: снимаем ", equipped_items[slot].display_name, " из ", slot)
		apply_special_bonuses(equipped_items[slot], false)
	
	equipped_items[slot] = null
	_clear_visual_for_slot(slot)
	_recompute_player_stats()
	_update_base_body_visibility()
	
	# Обновляем визуал всех слотов
	for slot_ui in get_tree().get_nodes_in_group("equipment_slot"):
		if slot_ui is EquipmentSlot and slot_ui.slot_type == slot:
			slot_ui.update_display()
	
	equipment_changed.emit(slot, null)
	return old_item


func get_item_in_slot(slot: String) -> ItemData:
	return equipped_items.get(slot, null)


func apply_special_bonuses(item: ItemData, is_equipping: bool = true) -> void:
	if not item.stat_additives.has("extra_hotbar_slots"):
		return
	
	var extra = item.stat_additives["extra_hotbar_slots"] as int
	
	var player = get_parent() as Player
	if not player or not player.hotbar_inventory:
		return
	
	if is_equipping:
		player.bonus_hotbar_slots += extra
	else:
		player.bonus_hotbar_slots -= extra
	var target_count: int = player.base_hotbar_slots + player.bonus_hotbar_slots
	if target_count < player.hotbar_inventory.slots_count:
		player.handle_hotbar_shrink(target_count)
	player.hotbar_inventory.set_slots_count(target_count)
	
	print("Hotbar now:", player.hotbar_inventory.slots_count)
	
	
	if player.hotbar_ui:
		player.hotbar_ui.refresh_slots()

func _update_visual_for_slot(slot: String) -> void:
	_clear_visual_for_slot(slot)
	var item: ItemData = equipped_items.get(slot, null)
	if item == null:
		return
	if item.equipped_model and skeleton and slot in ["Head","Chest","Legs","Feet","Hands"]:
		# Skinned meshes must point to the player's skeleton, like Eyes/Eyebrows in Player.tscn.
		# We instance the equipment under the Skeleton3D and bind all MeshInstance3D skins to it.
		var inst: Node3D = item.equipped_model.instantiate()
		skeleton.add_child(inst)
		call_deferred("_bind_equipment_meshes_to_skeleton", inst, skeleton)
		if slot == "Chest" and auto_fit_chest_scale:
			call_deferred("_auto_fit_chest_to_body", inst)
		if slot == "Chest":
			inst.position = chest_visual_offset
			inst.rotation_degrees = chest_visual_rotation
			inst.scale = chest_visual_scale
		equipped_visuals[slot] = inst

## Skinned retargeting intentionally not used here.
## To get animated armor like `Eyes`/`Eyebrows`, the armor mesh must be exported with the SAME skeleton as the player.

func _bind_equipment_meshes_to_skeleton(root: Node, target_skeleton: Skeleton3D) -> void:
	if not root or not target_skeleton:
		return
	if not root.is_inside_tree() or not target_skeleton.is_inside_tree():
		call_deferred("_bind_equipment_meshes_to_skeleton", root, target_skeleton)
		return
	
	# Traverse instanced equipment scene and bind any skinned meshes to the player's skeleton.
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		if mi.skin != null:
			# If mesh is a direct child of the skeleton, match Player.tscn style (`NodePath("..")`).
			if mi.get_parent() == target_skeleton:
				mi.skeleton = NodePath("..")
			else:
				mi.skeleton = mi.get_path_to(target_skeleton)
	
	for child in root.get_children():
		if child is Node:
			_bind_equipment_meshes_to_skeleton(child, target_skeleton)

func _update_base_body_visibility() -> void:
	var player := get_parent()
	if not player:
		return
	var base_body := player.get_node_or_null(base_body_mesh_path)
	if base_body and base_body is MeshInstance3D:
		# When chest equipment is present, hide the base torso mesh to prevent clipping/z-fighting.
		var has_chest: bool = (equipped_items.get("Chest", null) != null)
		(base_body as MeshInstance3D).visible = not has_chest

func _auto_fit_chest_to_body(chest_root: Node3D) -> void:
	if not auto_fit_chest_scale:
		return
	if not chest_root or not is_instance_valid(chest_root):
		return
	if not skeleton or not skeleton.is_inside_tree() or not chest_root.is_inside_tree():
		call_deferred("_auto_fit_chest_to_body", chest_root)
		return
	
	var player := get_parent()
	if not player:
		return
	var base_body := player.get_node_or_null(base_body_mesh_path)
	if not (base_body is MeshInstance3D):
		return
	
	var body_aabb := _compute_aabb_in_skeleton_space(base_body as MeshInstance3D, skeleton)
	var chest_aabb := _compute_combined_aabb_in_skeleton_space(chest_root, skeleton)
	
	if chest_aabb.size.length() <= 0.0001 or body_aabb.size.length() <= 0.0001:
		return
	
	# Uniform fit by horizontal footprint (x/z) to avoid making armor too tall.
	var body_h: float = maxf(body_aabb.size.x, body_aabb.size.z)
	var chest_h: float = maxf(chest_aabb.size.x, chest_aabb.size.z)
	if chest_h <= 0.0001:
		return
	
	var k: float = (body_h / chest_h) * auto_fit_chest_padding
	# Apply on top of user-provided scale.
	chest_root.scale = chest_visual_scale * k

func _compute_aabb_in_skeleton_space(mi: MeshInstance3D, skel: Skeleton3D) -> AABB:
	var aabb := mi.get_aabb()
	# Transform mesh-local AABB into skeleton space.
	var to_skel: Transform3D = skel.global_transform.affine_inverse() * mi.global_transform
	return _transform_aabb(aabb, to_skel)

func _transform_aabb(aabb: AABB, xform: Transform3D) -> AABB:
	# Godot 4 AABB doesn't provide transformed() like Godot 3.
	# Transform all 8 corners and rebuild an AABB.
	var p := aabb.position
	var s := aabb.size
	var corners := PackedVector3Array([
		p,
		p + Vector3(s.x, 0.0, 0.0),
		p + Vector3(0.0, s.y, 0.0),
		p + Vector3(0.0, 0.0, s.z),
		p + Vector3(s.x, s.y, 0.0),
		p + Vector3(s.x, 0.0, s.z),
		p + Vector3(0.0, s.y, s.z),
		p + s
	])
	
	var min_v := xform * corners[0]
	var max_v := min_v
	for i in range(1, corners.size()):
		var v := xform * corners[i]
		min_v = min_v.min(v)
		max_v = max_v.max(v)
	
	return AABB(min_v, max_v - min_v)

func _compute_combined_aabb_in_skeleton_space(root: Node, skel: Skeleton3D) -> AABB:
	var has_any: bool = false
	var combined := AABB()
	
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		var a := _compute_aabb_in_skeleton_space(mi, skel)
		combined = a
		has_any = true
	
	for child in root.get_children():
		if not (child is Node):
			continue
		var c_aabb := _compute_combined_aabb_in_skeleton_space(child, skel)
		if c_aabb.size.length() <= 0.0001:
			continue
		if not has_any:
			combined = c_aabb
			has_any = true
		else:
			combined = combined.merge(c_aabb)
	
	return combined if has_any else AABB()

func _clear_visual_for_slot(slot: String) -> void:
	var n = equipped_visuals.get(slot, null)
	if n and is_instance_valid(n):
		n.queue_free()
	equipped_visuals[slot] = null
	var sk = equipped_visual_skeletons.get(slot, null)
	if sk and is_instance_valid(sk):
		# Reset to rest pose (node will be freed anyway).
		sk.reset_bone_poses()
	equipped_visual_skeletons[slot] = null
	equipped_visual_bone_maps[slot] = null

func _recompute_player_stats() -> void:
	var player = get_parent()
	if not player:
		return
	var stats_comp = player.get_node_or_null("PlayerStatsComponent")
	if not stats_comp:
		return
	
	var additives := {}
	var multipliers := {}
	for it in equipped_items.values():
		if not it:
			continue
		for k in it.stat_additives.keys():
			if not additives.has(k):
				additives[k] = 0
			additives[k] += it.stat_additives[k]
		for m in it.stat_multipliers.keys():
			# multipliers stack multiplicatively around 1.0
			var mv = float(it.stat_multipliers[m])
			if not multipliers.has(m):
				multipliers[m] = 1.0
			multipliers[m] *= mv
	
	stats_comp.apply_equipment_modifiers(additives, multipliers)


func get_all_stats() -> Dictionary:
	var total := {}
	
	for item in equipped_items.values():
		if not item:
			continue
		
		for stat in item.stat_additives:
			if not total.has(stat):
				total[stat] = 0
			
			total[stat] += item.stat_additives[stat]
	
	return total
