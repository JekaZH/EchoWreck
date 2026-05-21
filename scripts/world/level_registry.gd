@tool
class_name LevelRegistry
extends Resource

## Каталог всех уровней проекта — удобно смотреть список и подставлять id в зонах.
@export var entries: Array[LevelEntry] = []


func find_entry(level_id: String) -> LevelEntry:
	for e in entries:
		if e != null and e.level_id == level_id:
			return e
	return null


func get_scene_path(level_id: String) -> String:
	var e := find_entry(level_id)
	if e == null:
		return ""
	return e.get_scene_path()


func get_display_name(level_id: String) -> String:
	var e := find_entry(level_id)
	if e == null:
		return level_id
	if not e.display_name.is_empty():
		return e.display_name
	return level_id
