extends CanvasLayer
class_name PauseMenuController

## Игровое меню (пауза): дочерний узел игрока или мира, `layer` выше обычного UI.

const SAVE_BROWSER_PATH := "res://scenes/ui/save_slots_browser.tscn"
const SETTINGS_PATH := "res://scenes/ui/settings_placeholder_menu.tscn"

@onready var _dimmer: ColorRect = $Root/Dimmer
@onready var _main_panel: PanelContainer = $Root/MainPanel
@onready var _continue_btn: Button = $Root/MainPanel/Margin/VBox/ContinueButton
@onready var _save_btn: Button = $Root/MainPanel/Margin/VBox/SaveButton
@onready var _load_btn: Button = $Root/MainPanel/Margin/VBox/LoadButton
@onready var _settings_btn: Button = $Root/MainPanel/Margin/VBox/SettingsButton
@onready var _exit_btn: Button = $Root/MainPanel/Margin/VBox/ExitButton

@onready var _subscreens: Control = $Root/SubScreens

var _load_browser: SaveSlotsBrowser
var _save_browser: SaveSlotsBrowser
var _settings_root: Control

var _pause_was_visible_for_screenshot: bool = false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_build_subscreens()
	_continue_btn.pressed.connect(close_menu)
	_save_btn.pressed.connect(_show_save_browser)
	_load_btn.pressed.connect(_show_load_browser)
	_settings_btn.pressed.connect(_show_settings)
	_exit_btn.pressed.connect(_on_exit_to_menu)
	SaveManager.before_screenshot_capture.connect(_on_before_save_screenshot)
	SaveManager.after_screenshot_capture.connect(_on_after_save_screenshot)


func _on_before_save_screenshot() -> void:
	_pause_was_visible_for_screenshot = visible
	hide()


func _on_after_save_screenshot() -> void:
	if _pause_was_visible_for_screenshot:
		show()


func _build_subscreens() -> void:
	var load_node := _instantiate_subscreen(SAVE_BROWSER_PATH)
	if load_node == null:
		return
	_load_browser = load_node as SaveSlotsBrowser
	_load_browser.hide()
	_load_browser.load_committed.connect(_on_load_slot)
	_load_browser.back_pressed.connect(_hide_subscreens)
	_subscreens.add_child(_load_browser)

	var save_node := _instantiate_subscreen(SAVE_BROWSER_PATH)
	if save_node == null:
		return
	_save_browser = save_node as SaveSlotsBrowser
	_save_browser.hide()
	_save_browser.save_committed.connect(_on_save_slot)
	_save_browser.back_pressed.connect(_hide_subscreens)
	_subscreens.add_child(_save_browser)

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
		push_error("pause_menu: cannot load scene %s" % path)
		return null
	var node := packed.instantiate()
	if node == null:
		push_error("pause_menu: cannot instantiate %s" % path)
	return node


func is_menu_open() -> bool:
	return visible


func open_menu() -> void:
	_hide_subscreens_internal()
	_main_panel.show()
	get_tree().paused = true
	show()


func close_menu() -> void:
	_hide_subscreens_internal()
	_main_panel.show()
	hide()
	get_tree().paused = false


func _show_save_browser() -> void:
	_main_panel.hide()
	_load_browser.hide()
	_settings_root.hide()
	_save_browser.set_mode(SaveSlotsBrowser.Mode.SAVE)
	_save_browser.show()
	_subscreens.show()


func _show_load_browser() -> void:
	_main_panel.hide()
	_save_browser.hide()
	_settings_root.hide()
	_load_browser.set_mode(SaveSlotsBrowser.Mode.LOAD)
	_load_browser.show()
	_subscreens.show()


func _show_settings() -> void:
	_main_panel.hide()
	_load_browser.hide()
	_save_browser.hide()
	_settings_root.show()
	_subscreens.show()


func _hide_subscreens() -> void:
	_hide_subscreens_internal()
	_main_panel.show()


func _hide_subscreens_internal() -> void:
	_subscreens.hide()
	_load_browser.hide()
	_save_browser.hide()
	_settings_root.hide()


func _on_load_slot(slot: int) -> void:
	get_tree().paused = false
	SaveManager.load_slot(slot)


func _on_save_slot(slot: int) -> void:
	await SaveManager.save_slot(slot)
	_save_browser.set_mode(SaveSlotsBrowser.Mode.SAVE)
	_hide_subscreens()


func _on_exit_to_menu() -> void:
	close_menu()
	SaveManager.go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _subscreens.visible and (_load_browser.visible or _save_browser.visible or _settings_root.visible):
			_hide_subscreens()
		elif _main_panel.visible:
			close_menu()
