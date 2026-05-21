extends Node

## Корневая папка слотов в user://
const SAVE_DIR := "user://saves"
const MAIN_GAME_PATH := "res://scenes/main.tscn"
const MAIN_MENU_PATH := "res://scenes/ui/main_menu/main_menu.tscn"

## Сколько слотов показывать в UI (0 … MAX−1).
const MAX_SAVE_SLOTS: int = 30

signal save_finished(slot: int, success: bool)
## Перед захватом кадра в файл превью (скрыть меню/UI); после — вернуть видимость.
signal before_screenshot_capture
signal after_screenshot_capture

var _pending_data: SaveGameData = null
var _pending_new_game: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_save_dir()


func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func get_slot_save_path(slot: int) -> String:
	return SAVE_DIR.path_join("slot_%03d.tres" % slot)


func get_slot_thumb_file_name(slot: int) -> String:
	return "slot_%03d.png" % slot


func get_slot_thumb_path(slot: int) -> String:
	return SAVE_DIR.path_join(get_slot_thumb_file_name(slot))


func slot_has_save(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_save_path(slot))


func load_save_resource(slot: int) -> SaveGameData:
	var p := get_slot_save_path(slot)
	if not FileAccess.file_exists(p):
		return null
	var res := load(p)
	return res as SaveGameData


func delete_save_slot(slot: int) -> bool:
	var tres_path := get_slot_save_path(slot)
	var png_path := get_slot_thumb_path(slot)
	var ok := true
	if FileAccess.file_exists(tres_path):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(tres_path))
		if err != OK:
			push_warning("SaveManager.delete_save_slot: не удалось удалить %s (%d)" % [tres_path, err])
			ok = false
	if FileAccess.file_exists(png_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(png_path))
	return ok


## Все найденные слоты с данными (для UI списка), по убыванию времени.
func list_saves_sorted() -> Array[Dictionary]:
	_ensure_save_dir()
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for name in dir.get_files():
		if name.begins_with("slot_") and name.ends_with(".tres"):
			var slot := _parse_slot_from_file(name)
			if slot >= 0:
				var data := load_save_resource(slot)
				if data:
					out.append({"slot": slot, "data": data})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["data"] as SaveGameData).unix_time > (b["data"] as SaveGameData).unix_time
	)
	return out


func _parse_slot_from_file(file_name: String) -> int:
	if not file_name.begins_with("slot_") or not file_name.ends_with(".tres"):
		return -1
	var base := file_name.get_basename()
	var num_str := base.substr(5)
	if num_str.is_valid_int():
		return int(num_str)
	return -1


func get_latest_slot() -> int:
	var lst := list_saves_sorted()
	if lst.is_empty():
		return -1
	return int(lst[0]["slot"])


func start_new_game() -> void:
	LevelWorldCache.clear_all()
	WorldPersistence.clear()
	LevelTravelManager.clear_travel_state()
	_pending_data = null
	_pending_new_game = true
	get_tree().change_scene_to_file(MAIN_GAME_PATH)


func load_slot(slot: int) -> void:
	var data := load_save_resource(slot)
	if data == null:
		push_warning("SaveManager: нет сохранения в слоте %d" % slot)
		return
	get_tree().paused = false
	LevelTravelManager.clear_travel_state()
	_pending_new_game = false
	_pending_data = data
	var level_path := LevelTravelManager.resolve_level_scene_path(data.level_scene_path)
	var packed := load(level_path) as PackedScene
	if packed == null:
		push_warning("SaveManager.load_slot: не удалось загрузить %s, fallback main" % level_path)
		get_tree().change_scene_to_file(MAIN_GAME_PATH)
	else:
		get_tree().change_scene_to_packed(packed)


func load_latest() -> void:
	var s := get_latest_slot()
	if s < 0:
		return
	load_slot(s)


func go_to_main_menu() -> void:
	get_tree().paused = false
	_pending_data = null
	_pending_new_game = false
	LevelWorldCache.clear_all()
	WorldPersistence.clear()
	LevelTravelManager.clear_travel_state()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


## Вызывать с корня игровой сцены (например `Main`) после появления игрока в дереве.
func apply_pending_to_game(main_root: Node) -> void:
	if _pending_new_game:
		_pending_new_game = false
		return
	if _pending_data == null:
		return
	var player := main_root.get_node_or_null("Player")
	if player is Node3D:
		(player as Node3D).global_transform = _pending_data.player_transform
	SaveGameState.apply_to_game(main_root as Node3D, _pending_data)
	_pending_data = null


func has_pending_save_data() -> bool:
	return _pending_data != null and not _pending_new_game


func save_slot(slot: int) -> bool:
	await get_tree().process_frame
	var tree := get_tree()
	if tree == null:
		return false
	var player := tree.get_first_node_in_group("player")
	if player == null or not (player is Player):
		push_warning("SaveManager.save_slot: нет игрока в группе player")
		return false
	var main := tree.current_scene as Node3D
	if main == null:
		push_warning("SaveManager.save_slot: current_scene не Node3D")
		return false
	var p := player as Player
	var data := SaveGameData.new()
	data.format_version = 3
	data.unix_time = Time.get_unix_time_from_system()
	if String(main.scene_file_path).length() > 0:
		data.level_scene_path = main.scene_file_path
	else:
		data.level_scene_path = "res://scenes/main.tscn"
	data.player_transform = p.global_transform
	data.screenshot_file_name = get_slot_thumb_file_name(slot)
	data.extension_data = SaveGameState.build_extension_data(main, p)

	_ensure_save_dir()
	var save_path := get_slot_save_path(slot)
	var err := ResourceSaver.save(data, save_path)
	if err != OK:
		push_error("SaveManager: ResourceSaver.save failed %d" % err)
		save_finished.emit(slot, false)
		return false

	before_screenshot_capture.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var img := _capture_viewport_image()
	after_screenshot_capture.emit()

	if img:
		var terr := img.save_png(get_slot_thumb_path(slot))
		if terr != OK:
			push_warning("SaveManager: screenshot save failed %d" % terr)

	save_finished.emit(slot, true)
	return true


func _capture_viewport_image() -> Image:
	var vp := get_viewport()
	if vp == null:
		return null
	var tex := vp.get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	return img


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var k := (event as InputEventKey).keycode
		if k == KEY_F5:
			call_deferred("_debug_quick_save")
		elif k == KEY_F9:
			if slot_has_save(0):
				load_slot(0)


func _debug_quick_save() -> void:
	await save_slot(0)
