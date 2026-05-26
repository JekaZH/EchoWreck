extends Node

## Корневая папка слотов в user://
const SAVE_DIR := "user://saves"
const MAIN_GAME_PATH := "res://scenes/main.tscn"
const MAIN_MENU_PATH := "res://scenes/ui/main_menu/main_menu.tscn"
const SETTINGS_PATH := "res://resources/save/save_manager_settings.tres"

## Ручные слоты в UI (0 … MAX−1). Автосейв — отдельный файл `autosave.tres`.
const MAX_SAVE_SLOTS: int = 30
## Специальный идентификатор слота в UI (только загрузка, без сохранения/удаления).
const AUTOSAVE_SLOT: int = -1
const AUTOSAVE_FILE := "autosave.tres"
const AUTOSAVE_THUMB := "autosave.png"

signal save_finished(slot: int, success: bool)
signal autosave_finished(success: bool)
signal before_screenshot_capture
signal after_screenshot_capture

var _pending_data: SaveGameData = null
var _pending_new_game: bool = false
var _settings: SaveManagerSettings
var _autosave_timer: Timer
var _has_unsaved_changes: bool = false
var _suppress_dirty: bool = false
var _autosave_in_progress: bool = false
var _bound_player: WeakRef
var _mark_dirty_on_next_boot: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_ensure_save_dir()
	_setup_autosave_timer()


func _load_settings() -> void:
	_settings = load(SETTINGS_PATH) as SaveManagerSettings
	if _settings == null:
		_settings = SaveManagerSettings.new()
		push_warning("SaveManager: не найден %s, используются значения по умолчанию" % SETTINGS_PATH)


func get_settings() -> SaveManagerSettings:
	return _settings


func _setup_autosave_timer() -> void:
	if _autosave_timer:
		_autosave_timer.queue_free()
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_autosave_timer.wait_time = maxf(_settings.autosave_interval_seconds, 30.0)
	_autosave_timer.autostart = false
	_autosave_timer.timeout.connect(_on_autosave_timer)
	add_child(_autosave_timer)
	_reset_autosave_timer()


func _reset_autosave_timer() -> void:
	if _autosave_timer:
		_autosave_timer.stop()
		_autosave_timer.start()


func _on_autosave_timer() -> void:
	if not _settings.autosave_enabled:
		return
	autosave_game()


func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func is_manual_slot(slot: int) -> bool:
	return slot >= 0 and slot < MAX_SAVE_SLOTS


func is_autosave_slot(slot: int) -> bool:
	return slot == AUTOSAVE_SLOT


func get_autosave_path() -> String:
	return SAVE_DIR.path_join(AUTOSAVE_FILE)


func get_autosave_thumb_path() -> String:
	return SAVE_DIR.path_join(AUTOSAVE_THUMB)


func get_slot_save_path(slot: int) -> String:
	return SAVE_DIR.path_join("slot_%03d.tres" % slot)


func get_slot_thumb_file_name(slot: int) -> String:
	return "slot_%03d.png" % slot


func get_slot_thumb_path(slot: int) -> String:
	return SAVE_DIR.path_join(get_slot_thumb_file_name(slot))


func autosave_has_data() -> bool:
	return FileAccess.file_exists(get_autosave_path())


func slot_has_save(slot: int) -> bool:
	if is_autosave_slot(slot):
		return autosave_has_data()
	if not is_manual_slot(slot):
		return false
	return FileAccess.file_exists(get_slot_save_path(slot))


func load_save_resource(slot: int) -> SaveGameData:
	var p := get_autosave_path() if slot < 0 else get_slot_save_path(slot)
	if not FileAccess.file_exists(p):
		return null
	var res := load(p)
	return res as SaveGameData


func load_autosave() -> SaveGameData:
	return load_save_resource(-1)


func delete_save_slot(slot: int) -> bool:
	if not is_manual_slot(slot):
		push_warning("SaveManager: нельзя удалить зарезервированный слот %d" % slot)
		return false
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


func list_saves_sorted() -> Array[Dictionary]:
	_ensure_save_dir()
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for name in dir.get_files():
		if name == AUTOSAVE_FILE:
			continue
		if name.begins_with("slot_") and name.ends_with(".tres"):
			var slot := _parse_slot_from_file(name)
			if is_manual_slot(slot):
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
	var best_slot := -1
	var best_time := -1.0
	if autosave_has_data():
		var auto_data := load_autosave()
		if auto_data:
			best_time = auto_data.unix_time
			best_slot = AUTOSAVE_SLOT
	for entry in list_saves_sorted():
		var data := entry["data"] as SaveGameData
		if data and data.unix_time > best_time:
			best_time = data.unix_time
			best_slot = int(entry["slot"])
	return best_slot


func mark_unsaved_changes() -> void:
	if _suppress_dirty:
		return
	_has_unsaved_changes = true


func clear_unsaved_changes() -> void:
	_has_unsaved_changes = false


func has_unsaved_changes() -> bool:
	return _has_unsaved_changes


func schedule_mark_dirty_on_next_boot() -> void:
	_mark_dirty_on_next_boot = true


func consume_mark_dirty_on_next_boot() -> bool:
	var v := _mark_dirty_on_next_boot
	_mark_dirty_on_next_boot = false
	return v


func should_warn_unsaved_on_exit() -> bool:
	return _settings.warn_unsaved_on_exit_to_menu and _has_unsaved_changes


func bind_gameplay_session(player: Player) -> void:
	unbind_gameplay_session()
	if player == null:
		return
	_bound_player = weakref(player)
	if player.inventory:
		if not player.inventory.changed.is_connected(_on_gameplay_changed):
			player.inventory.changed.connect(_on_gameplay_changed)
	if player.hotbar_inventory:
		if not player.hotbar_inventory.changed.is_connected(_on_gameplay_changed):
			player.hotbar_inventory.changed.connect(_on_gameplay_changed)
	if player.player_equipment:
		if not player.player_equipment.equipment_changed.is_connected(_on_gameplay_changed):
			player.player_equipment.equipment_changed.connect(_on_gameplay_changed)
	_reset_autosave_timer()


func unbind_gameplay_session() -> void:
	var player: Player = _bound_player.get_ref() if _bound_player else null
	if player != null and is_instance_valid(player):
		if player.inventory and player.inventory.changed.is_connected(_on_gameplay_changed):
			player.inventory.changed.disconnect(_on_gameplay_changed)
		if player.hotbar_inventory and player.hotbar_inventory.changed.is_connected(_on_gameplay_changed):
			player.hotbar_inventory.changed.disconnect(_on_gameplay_changed)
		if player.player_equipment and player.player_equipment.equipment_changed.is_connected(_on_gameplay_changed):
			player.player_equipment.equipment_changed.disconnect(_on_gameplay_changed)
	_bound_player = null
	if _autosave_timer:
		_autosave_timer.stop()


func _on_gameplay_changed(_arg1: Variant = null, _arg2: Variant = null) -> void:
	mark_unsaved_changes()


func _is_in_playable_game() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var scene := tree.current_scene
	if scene == null:
		return false
	var path := String(scene.scene_file_path)
	if path.is_empty():
		return false
	return not path.contains("main_menu") and not path.contains("death_screen")


func start_new_game() -> void:
	LevelWorldCache.clear_all()
	WorldPersistence.clear()
	LevelTravelManager.clear_travel_state()
	unbind_gameplay_session()
	_pending_data = null
	_pending_new_game = true
	_has_unsaved_changes = false
	schedule_mark_dirty_on_next_boot()
	_run_start_new_game()


func _run_start_new_game() -> void:
	await LevelTravelManager.transition_to_level(MAIN_GAME_PATH, "Новая игра...")


func load_slot(slot: int) -> void:
	if is_autosave_slot(slot):
		if not autosave_has_data():
			push_warning("SaveManager: автосохранение отсутствует")
			return
		_run_load_slot(AUTOSAVE_SLOT)
		return
	if not is_manual_slot(slot):
		push_warning("SaveManager: недопустимый ручной слот %d" % slot)
		return
	_run_load_slot(slot)


func load_autosave_slot() -> void:
	load_slot(AUTOSAVE_SLOT)


func _run_load_slot(slot: int) -> void:
	var data := load_save_resource(slot)
	if data == null:
		push_warning("SaveManager: нет сохранения в слоте %d" % slot)
		return
	get_tree().paused = false
	LevelTravelManager.clear_travel_state()
	_pending_new_game = false
	_pending_data = data
	_has_unsaved_changes = false
	var level_path := LevelTravelManager.resolve_level_scene_path(data.level_scene_path)
	await LevelTravelManager.transition_to_level(level_path, "Загрузка сохранения...")


func load_latest() -> void:
	var s := get_latest_slot()
	if s < 0:
		return
	load_slot(s)


func go_to_main_menu() -> void:
	get_tree().paused = false
	unbind_gameplay_session()
	_pending_data = null
	_pending_new_game = false
	_has_unsaved_changes = false
	LevelWorldCache.clear_all()
	WorldPersistence.clear()
	LevelTravelManager.clear_travel_state()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func apply_pending_to_game(main_root: Node) -> void:
	_suppress_dirty = true
	if _pending_new_game:
		_pending_new_game = false
		_suppress_dirty = false
		return
	if _pending_data == null:
		_suppress_dirty = false
		return
	var player := main_root.get_node_or_null("Player")
	if player is Node3D:
		(player as Node3D).global_transform = _pending_data.player_transform
	SaveGameState.apply_to_game(main_root as Node3D, _pending_data)
	_pending_data = null
	_suppress_dirty = false


func has_pending_save_data() -> bool:
	return _pending_data != null and not _pending_new_game


func save_slot(slot: int) -> bool:
	if not is_manual_slot(slot):
		push_warning("SaveManager: сохранение в слот %d запрещено" % slot)
		return false
	var ok := await _write_save_to_paths(get_slot_save_path(slot), get_slot_thumb_path(slot), slot)
	if ok:
		clear_unsaved_changes()
	return ok


func autosave_game() -> bool:
	if not _settings.autosave_enabled:
		return false
	if _autosave_in_progress:
		return false
	if not _is_in_playable_game():
		return false
	_autosave_in_progress = true
	var ok := await _write_save_to_paths(get_autosave_path(), get_autosave_thumb_path(), -1)
	_autosave_in_progress = false
	autosave_finished.emit(ok)
	_reset_autosave_timer()
	return ok


func _write_save_to_paths(save_path: String, thumb_path: String, slot_for_signal: int) -> bool:
	await get_tree().process_frame
	var tree := get_tree()
	if tree == null:
		return false
	var player := tree.get_first_node_in_group("player")
	if player == null or not (player is Player):
		push_warning("SaveManager: нет игрока в группе player")
		return false
	var main := tree.current_scene as Node3D
	if main == null:
		push_warning("SaveManager: current_scene не Node3D")
		return false
	var p := player as Player
	var data := SaveGameData.new()
	data.format_version = 3
	data.unix_time = Time.get_unix_time_from_system()
	if String(main.scene_file_path).length() > 0:
		data.level_scene_path = main.scene_file_path
	else:
		data.level_scene_path = MAIN_GAME_PATH
	data.player_transform = p.global_transform
	data.screenshot_file_name = thumb_path.get_file()
	data.extension_data = SaveGameState.build_extension_data(main, p)

	_ensure_save_dir()
	var abs_save_path := ProjectSettings.globalize_path(save_path)
	var err := ResourceSaver.save(data, abs_save_path)
	if err != OK:
		push_error("SaveManager: не удалось записать %s (код %d)" % [save_path, err])
		if slot_for_signal >= 0:
			save_finished.emit(slot_for_signal, false)
		elif slot_for_signal == AUTOSAVE_SLOT:
			autosave_finished.emit(false)
		return false

	before_screenshot_capture.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var img := _capture_viewport_image()
	after_screenshot_capture.emit()

	if img:
		var abs_thumb := ProjectSettings.globalize_path(thumb_path)
		var terr := img.save_png(abs_thumb)
		if terr != OK:
			push_warning("SaveManager: screenshot save failed %d" % terr)

	if slot_for_signal >= 0:
		save_finished.emit(slot_for_signal, true)
	elif slot_for_signal == AUTOSAVE_SLOT:
		autosave_finished.emit(true)
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
