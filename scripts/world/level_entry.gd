@tool
class_name LevelEntry
extends Resource

## Короткий id для каталога (латиница, без пробелов): `cave`, `village`.
@export var level_id: String = ""

## Название для UI / подсказок в редакторе.
@export var display_name: String = ""

## Сцена уровня из `res://scenes/levels/`.
@export var scene: PackedScene


func get_scene_path() -> String:
	if scene == null:
		return ""
	return scene.resource_path
