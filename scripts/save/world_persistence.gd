extends Node

## Обёртка для совместимости: состояние мира хранится в `LevelWorldCache` по сценам уровней.

func clear() -> void:
	LevelWorldCache.clear_all()


func set_from_save(arr: Variant) -> void:
	LevelWorldCache.set_removed_for_current_level(arr)


func register_removed(path_from_main: String) -> void:
	LevelWorldCache.register_removed_harvestable(path_from_main)


func get_removed() -> Array[String]:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return []
	var arr: Array = LevelWorldCache.get_removed_paths(tree.current_scene)
	var out: Array[String] = []
	for p in arr:
		if p is String:
			out.append(p)
	return out
