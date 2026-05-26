extends Node

## Кэш состояния мира **по каждой сцене уровня** (путь .tscn → payload).
## Живёт всю игровую сессию; при сохранении в слот уходит в SaveGameData.

var _levels: Dictionary = {}


func clear_all() -> void:
	_levels.clear()


func normalize_level_key(key: String) -> String:
	var k := key.strip_edges()
	if k.is_empty():
		return "res://scenes/main.tscn"
	if k.begins_with("uid://"):
		var path := ResourceUID.uid_to_path(k)
		if not path.is_empty():
			return path
	return k


func get_level_key(main: Node) -> String:
	if main == null:
		return normalize_level_key("")
	var custom: Variant = main.get("level_save_key")
	if custom is String and not str(custom).strip_edges().is_empty():
		return normalize_level_key(str(custom))
	var p := String(main.scene_file_path)
	return normalize_level_key(p)


func has_level(key: String) -> bool:
	var nk := normalize_level_key(key)
	return _levels.has(nk) and (_levels[nk] is Dictionary)


func get_level_payload(key: String) -> Dictionary:
	var nk := normalize_level_key(key)
	if has_level(nk):
		return (_levels[nk] as Dictionary).duplicate(true)
	return {}


func set_all_levels(levels: Variant) -> void:
	_levels.clear()
	if not (levels is Dictionary):
		return
	for raw_k in (levels as Dictionary).keys():
		var v: Variant = levels[raw_k]
		if not (v is Dictionary):
			continue
		var nk := normalize_level_key(str(raw_k))
		if _levels.has(nk) and (_levels[nk] is Dictionary):
			_merge_level_payload(_levels[nk] as Dictionary, v as Dictionary)
		else:
			_levels[nk] = (v as Dictionary).duplicate(true)


func set_removed_for_current_level(paths: Variant) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var key := get_level_key(tree.current_scene)
	var entry := _ensure_entry(key)
	if paths is Array:
		entry["removed_harvestables"] = (paths as Array).duplicate()
	else:
		entry["removed_harvestables"] = []


func get_all_levels() -> Dictionary:
	var out: Dictionary = {}
	for k in _levels.keys():
		out[k] = (_levels[k] as Dictionary).duplicate(true)
	return out


func _ensure_entry(key: String) -> Dictionary:
	var nk := normalize_level_key(key)
	if not _levels.has(nk) or not (_levels[nk] is Dictionary):
		_levels[nk] = {
			"removed_harvestables": [],
			"removed_enemies": [],
		}
	return _levels[nk] as Dictionary


func register_removed_harvestable(rel_path: String) -> void:
	_register_removed("removed_harvestables", rel_path)


func register_removed_enemy(rel_path: String) -> void:
	_register_removed("removed_enemies", rel_path)


func _register_removed(field: String, rel_path: String) -> void:
	if rel_path.is_empty():
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var key := get_level_key(tree.current_scene)
	var entry := _ensure_entry(key)
	var arr: Array = entry.get(field, []) as Array
	if not arr.has(rel_path):
		arr.append(rel_path)
	entry[field] = arr
	SaveManager.mark_unsaved_changes()


func get_removed_paths(main: Node) -> Array:
	return _get_removed_list(main, "removed_harvestables")


func get_removed_enemy_paths(main: Node) -> Array:
	return _get_removed_list(main, "removed_enemies")


func _get_removed_list(main: Node, field: String) -> Array:
	var entry := get_level_payload(get_level_key(main))
	var arr: Variant = entry.get(field, [])
	if arr is Array:
		return arr.duplicate()
	return []


func capture_level(main: Node3D) -> void:
	if main == null:
		return
	var key := get_level_key(main)
	var removed_h: Array = get_removed_paths(main)
	var removed_e: Array = get_removed_enemy_paths(main)
	_levels[key] = SaveGameState.build_world_payload(main, removed_h, removed_e)


func apply_level(main: Node3D) -> void:
	if main == null:
		return
	var key := get_level_key(main)
	if not has_level(key):
		return
	SaveGameState.apply_world_payload(main, get_level_payload(key))


func _merge_level_payload(dst: Dictionary, src: Dictionary) -> void:
	for field in ["removed_harvestables", "removed_enemies"]:
		var merged: Array = dst.get(field, []) as Array
		for p in src.get(field, []) as Array:
			if p is String and not merged.has(p):
				merged.append(p)
		dst[field] = merged
	for field in ["dropped_items", "chests", "crafting_stations"]:
		if src.has(field):
			dst[field] = src[field]
