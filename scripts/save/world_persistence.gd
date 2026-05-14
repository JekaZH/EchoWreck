extends Node

## Пути узлов добычи (относительно `current_scene`), которые уже уничтожены в этой сессии / в загруженном сейве.

var removed_harvest_paths: Array[String] = []


func clear() -> void:
	removed_harvest_paths.clear()


func set_from_save(arr: Variant) -> void:
	removed_harvest_paths.clear()
	if arr is Array:
		for p in arr:
			if p is String and (p as String).length() > 0:
				if not removed_harvest_paths.has(p):
					removed_harvest_paths.append(p)


func register_removed(path_from_main: String) -> void:
	if path_from_main.is_empty():
		return
	if not removed_harvest_paths.has(path_from_main):
		removed_harvest_paths.append(path_from_main)


func get_removed() -> Array[String]:
	var out: Array[String] = []
	for p in removed_harvest_paths:
		out.append(p)
	return out
