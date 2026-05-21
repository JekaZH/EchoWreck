extends Control

## Главное меню: фон и кнопки настраиваются в сцене `main_menu.tscn`.

const SAVE_BROWSER_PATH := "res://scenes/ui/save_slots_browser.tscn"
const SETTINGS_PATH := "res://scenes/ui/settings_placeholder_menu.tscn"

@onready var _main_panel: Control = $SafeArea/MainPanel
@onready var _new_game_btn: Button = $SafeArea/MainPanel/Margin/VBox/NewGameButton
@onready var _continue_btn: Button = $SafeArea/MainPanel/Margin/VBox/ContinueButton
@onready var _load_btn: Button = $SafeArea/MainPanel/Margin/VBox/LoadButton
@onready var _settings_btn: Button = $SafeArea/MainPanel/Margin/VBox/SettingsButton
@onready var _quit_btn: Button = $SafeArea/MainPanel/Margin/VBox/QuitButton

@onready var _subscreens: Control = $SafeArea/SubScreens

var _load_browser: SaveSlotsBrowser
var _settings_root: Control


func _ready() -> void:
	_refresh_continue_visibility()
	_new_game_btn.pressed.connect(_on_new_game)
	_continue_btn.pressed.connect(_on_continue)
	_load_btn.pressed.connect(_show_load_browser)
	_settings_btn.pressed.connect(_show_settings)
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	_subscreens.hide()
	_build_subscreens()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_continue_visibility()


func _refresh_continue_visibility() -> void:
	if not is_node_ready() or _continue_btn == null:
		return
	var has_saves := SaveManager.get_latest_slot() >= 0
	_continue_btn.visible = has_saves


func _build_subscreens() -> void:
	var browser := _instantiate_subscreen(SAVE_BROWSER_PATH)
	if browser == null:
		return
	_load_browser = browser as SaveSlotsBrowser
	_load_browser.hide()
	_load_browser.load_committed.connect(_on_load_slot_chosen)
	_load_browser.back_pressed.connect(_hide_subscreens)
	_subscreens.add_child(_load_browser)

	var settings := _instantiate_subscreen(SETTINGS_PATH)
	if settings == null:
		return
	_settings_root = settings as Control
	_settings_root.hide()
	_settings_root.connect("back_pressed", Callable(self, "_hide_subscreens"))
	_subscreens.add_child(_settings_root)


func _instantiate_subscreen(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("main_menu: cannot load scene %s" % path)
		return null
	var node := packed.instantiate()
	if node == null:
		push_error("main_menu: cannot instantiate %s" % path)
	return node


func _on_continue() -> void:
	SaveManager.load_latest()


func _on_new_game() -> void:
	SaveManager.start_new_game()


func _show_load_browser() -> void:
	if _load_browser == null:
		return
	_main_panel.hide()
	if _settings_root:
		_settings_root.hide()
	_load_browser.set_mode(SaveSlotsBrowser.Mode.LOAD)
	_load_browser.show()
	_subscreens.show()


func _show_settings() -> void:
	if _settings_root == null:
		return
	_main_panel.hide()
	if _load_browser:
		_load_browser.hide()
	_settings_root.show()
	_subscreens.show()


func _hide_subscreens() -> void:
	_subscreens.hide()
	if _load_browser:
		_load_browser.hide()
	if _settings_root:
		_settings_root.hide()
	_main_panel.show()
	_refresh_continue_visibility()


func _on_load_slot_chosen(slot: int) -> void:
	SaveManager.load_slot(slot)
