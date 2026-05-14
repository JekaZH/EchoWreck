class_name SaveGameState
extends RefCounted

const DROPPED_SCENE := preload("res://scenes/world_objects/dropped_item/dropped_item.tscn")

const EQUIPMENT_SLOTS: Array[String] = [
	"Head", "Chest", "Legs", "Feet", "Hands", "Belt", "Ring", "Amulet"
]

static var _item_by_id_cache: Dictionary = {}


static func _resolve_item(d: Dictionary) -> ItemData:
	if d.is_empty():
		return null
	var path: String = str(d.get("path", ""))
	if path.length() > 0 and ResourceLoader.exists(path):
		return load(path) as ItemData
	var id: String = str(d.get("id", ""))
	if id.is_empty():
		return null
	if _item_by_id_cache.is_empty():
		_build_item_id_cache()
	return _item_by_id_cache.get(id) as ItemData


static func _build_item_id_cache() -> void:
	_item_by_id_cache.clear()
	var dir := DirAccess.open("res://resources/items/")
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var full := "res://resources/items/%s" % f
		var item := load(full) as ItemData
		if item and not item.id.is_empty():
			_item_by_id_cache[item.id] = item


static func item_stack_to_dict(stack: ItemStack) -> Dictionary:
	if stack == null or stack.item == null:
		return {}
	return {
		"path": stack.item.resource_path,
		"id": stack.item.id,
		"count": stack.count,
	}


static func dict_to_stack(d: Dictionary) -> ItemStack:
	var item := _resolve_item(d)
	if item == null:
		return null
	var c: int = int(d.get("count", 1))
	var mx: int = maxi(item.max_stack, 1)
	return ItemStack.new(item, clampi(c, 1, mx))


static func serialize_inventory(inv: Inventory) -> Array:
	var out: Array = []
	if inv == null:
		return out
	for i in inv.slots_count:
		var st := inv.get_slot(i)
		if st and st.item:
			out.append(item_stack_to_dict(st))
		else:
			out.append({})
	return out


static func apply_inventory(inv: Inventory, data: Variant) -> void:
	if inv == null or not (data is Array):
		return
	var arr := data as Array
	for i in inv.slots_count:
		inv.clear_slot(i)
	for i in mini(arr.size(), inv.slots_count):
		var cell = arr[i]
		if cell is Dictionary and not (cell as Dictionary).is_empty():
			var st := dict_to_stack(cell as Dictionary)
			if st:
				inv.set_slot(i, st)
	inv.changed.emit()


static func serialize_stats(stats: PlayerStats) -> Dictionary:
	if stats == null:
		return {}
	return {
		"max_health": stats.max_health,
		"health": stats.health,
		"max_hunger": stats.max_hunger,
		"hunger": stats.hunger,
		"max_thirst": stats.max_thirst,
		"thirst": stats.thirst,
		"max_energy": stats.max_energy,
		"energy": stats.energy,
		"custom_stats": stats.custom_stats.duplicate(true),
	}


static func apply_stats(stats: PlayerStats, d: Variant) -> void:
	if stats == null or not (d is Dictionary):
		return
	var dict := d as Dictionary
	stats.max_health = float(dict.get("max_health", stats.max_health))
	stats.health = clampf(float(dict.get("health", stats.health)), 0.0, stats.max_health)
	stats.max_hunger = float(dict.get("max_hunger", stats.max_hunger))
	stats.hunger = clampf(float(dict.get("hunger", stats.hunger)), 0.0, stats.max_hunger)
	stats.max_thirst = float(dict.get("max_thirst", stats.max_thirst))
	stats.thirst = clampf(float(dict.get("thirst", stats.thirst)), 0.0, stats.max_thirst)
	stats.max_energy = float(dict.get("max_energy", stats.max_energy))
	stats.energy = clampf(float(dict.get("energy", stats.energy)), 0.0, stats.max_energy)
	if dict.has("custom_stats") and dict["custom_stats"] is Dictionary:
		stats.custom_stats = (dict["custom_stats"] as Dictionary).duplicate(true)


static func serialize_equipment(eq: PlayerEquipment) -> Dictionary:
	var out := {}
	if eq == null:
		return out
	for slot in EQUIPMENT_SLOTS:
		var it: ItemData = eq.get_item_in_slot(slot)
		if it:
			out[slot] = item_stack_to_dict(ItemStack.new(it, 1))
		else:
			out[slot] = {}
	return out


static func apply_equipment(eq: PlayerEquipment, data: Variant) -> void:
	if eq == null:
		return
	for slot in EQUIPMENT_SLOTS:
		eq.unequip_slot(slot)
	if not (data is Dictionary):
		return
	var dict := data as Dictionary
	for slot in EQUIPMENT_SLOTS:
		var cell = dict.get(slot, {})
		if cell is Dictionary and not (cell as Dictionary).is_empty():
			var it := _resolve_item(cell as Dictionary)
			if it:
				eq.equip_item(it)


static func serialize_chests(main: Node) -> Dictionary:
	var out := {}
	if main == null:
		return out
	for n in main.get_tree().get_nodes_in_group("persist_chest"):
		if not (n is Chest):
			continue
		if not main.is_ancestor_of(n):
			continue
		var chest := n as Chest
		if chest.inventory == null:
			continue
		var rel := str(main.get_path_to(chest))
		out[rel] = serialize_inventory(chest.inventory)
	return out


static func apply_chests(main: Node, data: Variant) -> void:
	if main == null or not (data is Dictionary):
		return
	var dict := data as Dictionary
	for rel in dict.keys():
		var path_str := str(rel)
		var node := main.get_node_or_null(path_str)
		if node == null or not (node is Chest):
			continue
		var chest := node as Chest
		if chest.inventory:
			apply_inventory(chest.inventory, dict[rel])


static func serialize_crafting_stations(main: Node) -> Dictionary:
	var out := {}
	if main == null:
		return out
	for n in main.get_tree().get_nodes_in_group("persist_crafting_station"):
		if not (n is CraftingStation):
			continue
		if not main.is_ancestor_of(n):
			continue
		var st := n as CraftingStation
		if st.output_inventory == null and st.fuel_inventory == null:
			continue
		var entry := {}
		entry["fuel_buffer_seconds"] = st.get_fuel_buffer_seconds()
		if st.fuel_inventory:
			entry["fuel"] = serialize_inventory(st.fuel_inventory)
		if st.output_inventory:
			entry["output"] = serialize_inventory(st.output_inventory)
		out[str(main.get_path_to(st))] = entry
	return out


static func apply_crafting_stations(main: Node, data: Variant) -> void:
	if main == null or not (data is Dictionary):
		return
	var dict := data as Dictionary
	for rel in dict.keys():
		var path_str := str(rel)
		var node := main.get_node_or_null(path_str)
		if node == null or not (node is CraftingStation):
			continue
		var st := node as CraftingStation
		var entry_v: Variant = dict[rel]
		if not (entry_v is Dictionary):
			continue
		var entry := entry_v as Dictionary
		if st.fuel_inventory and entry.has("fuel"):
			apply_inventory(st.fuel_inventory, entry["fuel"])
		if st.output_inventory and entry.has("output"):
			apply_inventory(st.output_inventory, entry["output"])
		st.restore_persisted_fuel_buffer_seconds(float(entry.get("fuel_buffer_seconds", 0.0)))


static func collect_dropped_items(main: Node) -> Array:
	var out: Array = []
	if main == null:
		return out
	for n in main.get_tree().get_nodes_in_group("dropped_items"):
		if not (n is DroppedItem):
			continue
		if not main.is_ancestor_of(n):
			continue
		var d := n as DroppedItem
		if d.item_data == null:
			continue
		out.append({
			"item": item_stack_to_dict(ItemStack.new(d.item_data, d.count)),
			"pos": {"x": d.global_position.x, "y": d.global_position.y, "z": d.global_position.z},
			"rot_y": d.global_rotation.y,
		})
	return out


static func clear_dropped_items(main: Node) -> void:
	if main == null:
		return
	var to_free: Array[Node] = []
	for n in main.get_tree().get_nodes_in_group("dropped_items"):
		if not is_instance_valid(n):
			continue
		if not (n is DroppedItem):
			continue
		if main.is_ancestor_of(n):
			to_free.append(n)
	for n in to_free:
		n.queue_free()


static func spawn_dropped_items(main: Node, data: Variant) -> void:
	if main == null or not (data is Array):
		return
	var tree := main.get_tree()
	for entry in data as Array:
		if not (entry is Dictionary):
			continue
		var e := entry as Dictionary
		var item_v: Variant = e.get("item", {})
		if not (item_v is Dictionary):
			continue
		var st := dict_to_stack(item_v as Dictionary)
		if st == null:
			continue
		var posd: Variant = e.get("pos", {})
		if not (posd is Dictionary):
			continue
		var pd := posd as Dictionary
		var pos := Vector3(float(pd.get("x", 0.0)), float(pd.get("y", 0.0)), float(pd.get("z", 0.0)))
		var rot_y: float = float(e.get("rot_y", 0.0))
		var dropped := DROPPED_SCENE.instantiate() as DroppedItem
		dropped.item_data = st.item
		dropped.count = st.count
		tree.current_scene.add_child(dropped)
		dropped.global_position = pos
		dropped.global_rotation = Vector3(0.0, rot_y, 0.0)
		dropped.add_to_group("dropped_items")


static func apply_destroyed_harvestables(main: Node, paths: Variant) -> void:
	if main == null or not (paths is Array):
		return
	var to_kill: Array[Node] = []
	for p in paths as Array:
		if not (p is String):
			continue
		var node := main.get_node_or_null(str(p))
		if node and is_instance_valid(node):
			to_kill.append(node)
	for n in to_kill:
		n.queue_free()


static func build_extension_data(main: Node3D, player: Player) -> Dictionary:
	var ext := {}
	ext["format_payload"] = 2
	ext["removed_harvestables"] = WorldPersistence.get_removed()
	ext["dropped_items"] = collect_dropped_items(main)
	ext["player_inventory"] = serialize_inventory(player.inventory)
	ext["hotbar_inventory"] = serialize_inventory(player.hotbar_inventory) if player.hotbar_inventory else []
	ext["hotbar_slots"] = player.hotbar_inventory.slots_count if player.hotbar_inventory else player.base_hotbar_slots
	ext["player_stats"] = serialize_stats(player.stats_component.stats)
	ext["player_equipment"] = serialize_equipment(player.player_equipment)
	ext["chests"] = serialize_chests(main)
	ext["crafting_stations"] = serialize_crafting_stations(main)
	return ext


static func apply_to_game(main: Node3D, data: SaveGameData) -> void:
	if data == null or main == null:
		return
	var ext: Dictionary = data.extension_data if data.extension_data else {}
	var player := main.get_node_or_null("Player") as Player
	if player == null:
		return
	# Старые сейвы без полного payload — не трогаем мир и инвентарь.
	if int(ext.get("format_payload", 0)) < 2:
		return

	WorldPersistence.set_from_save(ext.get("removed_harvestables", []))
	apply_destroyed_harvestables(main, ext.get("removed_harvestables", []))

	clear_dropped_items(main)
	spawn_dropped_items(main, ext.get("dropped_items", []))

	apply_stats(player.stats_component.stats, ext.get("player_stats", {}))

	for slot in EQUIPMENT_SLOTS:
		player.player_equipment.unequip_slot(slot)

	apply_inventory(player.inventory, ext.get("player_inventory", []))

	apply_equipment(player.player_equipment, ext.get("player_equipment", {}))

	if player.hotbar_inventory == null:
		push_warning("SaveGameState.apply_to_game: hotbar_inventory отсутствует, пропуск восстановления хотбара")
	else:
		var hb_slots: int = int(ext.get("hotbar_slots", player.hotbar_inventory.slots_count))
		hb_slots = maxi(hb_slots, player.hotbar_inventory.slots_count)
		player.hotbar_inventory.set_slots_count(hb_slots)
		apply_inventory(player.hotbar_inventory, ext.get("hotbar_inventory", []))

	apply_chests(main, ext.get("chests", {}))
	apply_crafting_stations(main, ext.get("crafting_stations", {}))

	if player.stats_ui:
		player.stats_ui.setup(player.stats_component.stats)

	if player.hotbar_ui and player.hotbar_inventory:
		player.hotbar_ui.slot_count = player.hotbar_inventory.slots_count
		player.hotbar_ui.refresh_slots()
		var max_idx := player.hotbar_inventory.slots_count - 1
		if player.hotbar_ui.active_slot_index >= 0 and max_idx >= 0:
			player.hotbar_ui.select_slot(mini(player.hotbar_ui.active_slot_index, max_idx))
		else:
			player.update_equipped_tool_from_hotbar()

	player.player_equipment._recompute_player_stats()

	player.inventory.changed.emit()
	if player.hotbar_inventory:
		player.hotbar_inventory.changed.emit()
