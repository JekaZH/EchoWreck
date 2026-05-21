extends CanvasLayer
class_name DeathScreenController

const SAVE_BROWSER_PATH := "res://scenes/ui/save_slots_browser.tscn"

@onready var _dimmer: ColorRect = $Root/Dimmer
@onready var _main_panel: PanelContainer = $Root/MainPanel
@onready var _latest_btn: Button = $Root/MainPanel/Margin/VBox/LatestSaveButton
@onready var _load_btn: Button = $Root/MainPanel/Margin/VBox/LoadButton
@onready var _menu_btn: Button = $Root/MainPanel/Margin/VBox/MainMenuButton
@onready var _subscreens: Control = $Root/SubScreens

var _load_browser: SaveSlotsBrowser


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_build_subscreens()
	_latest_btn.pressed.connect(_on_load_latest)
	_load_btn.pressed.connect(_show_load_browser)
	_menu_btn.pressed.connect(_on_main_menu)
	_refresh_latest_button()


func _build_subscreens() -> void:
	var packed := load(SAVE_BROWSER_PATH) as PackedScene
	if packed == null:
		push_error("death_screen: cannot load %s" % SAVE_BROWSER_PATH)
		return
	var browser := packed.instantiate()
	if browser == null:
		push_error("death_screen: cannot instantiate %s" % SAVE_BROWSER_PATH)
		return
	_load_browser = browser as SaveSlotsBrowser
	_load_browser.hide()
	_load_browser.load_committed.connect(_on_load_slot)
	_load_browser.back_pressed.connect(_hide_load_browser)
	_subscreens.add_child(_load_browser)


func is_open() -> bool:
	return visible


func open_screen() -> void:
	_refresh_latest_button()
	_hide_load_browser_internal()
	_main_panel.show()
	get_tree().paused = true
	show()


func close_screen() -> void:
	_hide_load_browser_internal()
	_main_panel.show()
	hide()
	get_tree().paused = false


func _refresh_latest_button() -> void:
	var has_save := SaveManager.get_latest_slot() >= 0
	_latest_btn.disabled = not has_save


func _show_load_browser() -> void:
	_main_panel.hide()
	_load_browser.set_mode(SaveSlotsBrowser.Mode.LOAD, "Загрузить сохранение")
	_load_browser.show()
	_subscreens.show()


func _hide_load_browser() -> void:
	_hide_load_browser_internal()
	_main_panel.show()


func _hide_load_browser_internal() -> void:
	_subscreens.hide()
	_load_browser.hide()


func _on_load_latest() -> void:
	var slot := SaveManager.get_latest_slot()
	if slot < 0:
		return
	get_tree().paused = false
	SaveManager.load_slot(slot)


func _on_load_slot(slot: int) -> void:
	get_tree().paused = false
	SaveManager.load_slot(slot)


func _on_main_menu() -> void:
	get_tree().paused = false
	SaveManager.go_to_main_menu()
