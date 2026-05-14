extends Control
class_name SaveSlotsBrowser

enum Mode { LOAD, SAVE }

signal back_pressed
signal load_committed(slot: int)
signal save_committed(slot: int)

@onready var _title: Label = $Margin/VBox/TitleLabel
@onready var _item_list: ItemList = $Margin/VBox/ItemList
@onready var _action_btn: Button = $Margin/VBox/HBox/ActionButton
@onready var _delete_btn: Button = $Margin/VBox/HBox/DeleteButton
@onready var _back_btn: Button = $Margin/VBox/HBox/BackButton
@onready var _hint: Label = $Margin/VBox/HintLabel

var _mode: Mode = Mode.LOAD
var _slot_by_item_index: Array[int] = []
var _pending_overwrite_slot: int = -1
var _pending_delete_slot: int = -1

@onready var _overwrite_confirm: ConfirmationDialog = $OverwriteConfirm
@onready var _delete_confirm: ConfirmationDialog = $DeleteConfirm


func _ready() -> void:
	_overwrite_confirm.confirmed.connect(_on_overwrite_confirmed)
	_overwrite_confirm.canceled.connect(func() -> void: _pending_overwrite_slot = -1)
	_delete_confirm.confirmed.connect(_on_delete_confirmed)
	_delete_confirm.canceled.connect(func() -> void: _pending_delete_slot = -1)
	_back_btn.pressed.connect(func() -> void: back_pressed.emit())
	_action_btn.pressed.connect(_on_action_pressed)
	_delete_btn.pressed.connect(_on_delete_pressed)
	_item_list.item_activated.connect(_on_item_activated)
	_item_list.item_selected.connect(_on_item_selected)


func set_mode(m: Mode, custom_title: String = "") -> void:
	_mode = m
	if custom_title != "":
		_title.text = custom_title
	else:
		_title.text = "Загрузить игру" if m == Mode.LOAD else "Сохранить игру"
	_action_btn.text = "Загрузить" if m == Mode.LOAD else "Сохранить в слот"
	_hint.text = (
		"Сверху — самые новые сохранения, ниже — пустые слоты. Двойной клик — быстро загрузить."
		if m == Mode.LOAD
		else "Сверху — занятые слоты (новые выше). Пустой слот сохраняется сразу; занятый — с подтверждением."
	)
	_rebuild_list()
	_update_delete_enabled()


func _rebuild_list() -> void:
	_item_list.clear()
	_slot_by_item_index.clear()
	var used: Dictionary = {}
	for entry in SaveManager.list_saves_sorted():
		var slot: int = int(entry["slot"])
		_append_row(slot)
		used[slot] = true
	for s in range(SaveManager.MAX_SAVE_SLOTS):
		if used.has(s):
			continue
		_append_row(s)
	_update_delete_enabled()


func _append_row(slot: int) -> void:
	var line := _format_slot_line(slot)
	var icon: Texture2D = _load_thumb_texture(slot)
	if icon:
		_item_list.add_item(line, icon)
	else:
		_item_list.add_item(line)
	_slot_by_item_index.append(slot)


func _format_slot_line(slot: int) -> String:
	var prefix := "Слот %02d — " % (slot + 1)
	if not SaveManager.slot_has_save(slot):
		return prefix + "пусто"
	var d := SaveManager.load_save_resource(slot)
	if d == null:
		return prefix + "ошибка чтения"
	return prefix + Time.get_datetime_string_from_unix_time(int(d.unix_time))


func _load_thumb_texture(slot: int) -> Texture2D:
	var thumb := SaveManager.get_slot_thumb_path(slot)
	if not FileAccess.file_exists(thumb):
		return null
	var abs_path := ProjectSettings.globalize_path(thumb)
	var img := Image.load_from_file(abs_path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


func _selected_slot() -> int:
	var sel := _item_list.get_selected_items()
	if sel.is_empty():
		return -1
	var idx: int = sel[0]
	if idx < 0 or idx >= _slot_by_item_index.size():
		return -1
	return _slot_by_item_index[idx]


func _on_item_selected(_index: int) -> void:
	_update_delete_enabled()


func _update_delete_enabled() -> void:
	var s := _selected_slot()
	_delete_btn.disabled = s < 0 or not SaveManager.slot_has_save(s)


func _on_action_pressed() -> void:
	var slot := _selected_slot()
	if slot < 0:
		return
	if _mode == Mode.LOAD:
		if SaveManager.slot_has_save(slot):
			load_committed.emit(slot)
	elif _mode == Mode.SAVE:
		_try_commit_save(slot)


func _on_delete_pressed() -> void:
	var slot := _selected_slot()
	if slot < 0 or not SaveManager.slot_has_save(slot):
		return
	_pending_delete_slot = slot
	_delete_confirm.dialog_text = "Удалить сохранение в слоте %d?\nФайл будет удалён безвозвратно." % (slot + 1)
	_delete_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	if _pending_delete_slot < 0:
		return
	SaveManager.delete_save_slot(_pending_delete_slot)
	_pending_delete_slot = -1
	_rebuild_list()


func _on_item_activated(index: int) -> void:
	if index < 0 or index >= _slot_by_item_index.size():
		return
	var slot: int = _slot_by_item_index[index]
	if _mode == Mode.LOAD:
		if SaveManager.slot_has_save(slot):
			load_committed.emit(slot)
	elif _mode == Mode.SAVE:
		_try_commit_save(slot)


func _try_commit_save(slot: int) -> void:
	if SaveManager.slot_has_save(slot):
		_pending_overwrite_slot = slot
		_overwrite_confirm.dialog_text = "Перезаписать слот %d?\nТекущее сохранение будет заменено." % (slot + 1)
		_overwrite_confirm.popup_centered()
	else:
		save_committed.emit(slot)


func _on_overwrite_confirmed() -> void:
	if _pending_overwrite_slot >= 0:
		save_committed.emit(_pending_overwrite_slot)
	_pending_overwrite_slot = -1
