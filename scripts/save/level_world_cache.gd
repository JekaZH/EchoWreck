extends Node

## Кэш состояния мира **по каждой сцене уровня** (путь .tscn → payload).
## Живёт всю игровую сессию; при сохранении в слот уходит в SaveGameData.

var _levels: Dictionary = {}


func clear_all() -> void:
	_levels.clear()


func get_level_key(main: Node) -> String:
	if main == null:
		return ""
	var p := String(main.scene_file_path)
	if p.is_empty():
		p = "res://scenes/main.tscn"
	return p


func has_level(key: String) -> bool:
	return _levels.has(key) and (_levels[key] is Dictionary)


func get_level_payload(key: String) -> Dictionary:
	if has_level(key):
		return (_levels[key] as Dictionary).duplicate(true)
	return {}


func set_all_levels(levels: Variant) -> void:
	_levels.clear()
	if levels is Dictionary:
		for k in (levels as Dictionary).keys():
			var v: Variant = levels[k]
			if v is Dictionary:
				_levels[str(k)] = (v as Dictionary).duplicate(true)


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
	return _levels.duplicate(true)


func _ensure_entry(key: String) -> Dictionary:
	if not _levels.has(key) or not (_levels[key] is Dictionary):
		_levels[key] = {"removed_harvestables": []}
	return _levels[key] as Dictionary


func register_removed_harvestable(rel_path: String) -> void:
	if rel_path.is_empty():
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var key := get_level_key(tree.current_scene)
	var entry := _ensure_entry(key)
	var arr: Array = entry.get("removed_harvestables", []) as Array
	if not arr.has(rel_path):
		arr.append(rel_path)
	entry["removed_harvestables"] = arr


func get_removed_paths(main: Node) -> Array:
	var entry := get_level_payload(get_level_key(main))
	var arr: Variant = entry.get("removed_harvestables", [])
	if arr is Array:
		return arr.duplicate()
	return []


func capture_level(main: Node3D) -> void:
	if main == null:
		return
	var key := get_level_key(main)
	var removed: Array = get_removed_paths(main)
	_levels[key] = SaveGameState.build_world_payload(main, removed)


func apply_level(main: Node3D) -> void:
	if main == null:
		return
	var key := get_level_key(main)
	if not has_level(key):
		return
	SaveGameState.apply_world_payload(main, get_level_payload(key))
