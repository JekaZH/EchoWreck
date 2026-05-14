class_name SaveGameData
extends Resource

## Версия формата файла (увеличивать при несовместимых изменениях схемы).
@export var format_version: int = 1

## Unix-время сохранения (для сортировки и подписи в UI).
@export var unix_time: float = 0.0

## Сцена уровня, с которой сохранялись (для будущих переходов между уровнями).
@export var level_scene_path: String = "res://scenes/main.tscn"

## Положение игрока в мире.
@export var player_transform: Transform3D = Transform3D.IDENTITY

## Имя файла превью рядом с .tres, например "slot_003.png" (в той же папке user://saves/).
@export var screenshot_file_name: String = ""

## Расширяемое хранилище: инвентарь, сундуки, квесты — отдельными ключами по мере готовности.
@export var extension_data: Dictionary = {}


func get_thumbnail_path(save_dir: String) -> String:
	if screenshot_file_name.is_empty():
		return ""
	return save_dir.path_join(screenshot_file_name)
