extends CanvasLayer
class_name LevelTravelConfirmController

signal confirmed
signal cancelled

@onready var _dimmer: ColorRect = $Root/Dimmer
@onready var _panel: PanelContainer = $Root/Panel
@onready var _label: Label = $Root/Panel/Margin/VBox/MessageLabel
@onready var _yes_btn: Button = $Root/Panel/Margin/VBox/Buttons/YesButton
@onready var _no_btn: Button = $Root/Panel/Margin/VBox/Buttons/NoButton


func _ready() -> void:
	layer = 115
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_yes_btn.pressed.connect(func() -> void:
		hide()
		confirmed.emit()
	)
	_no_btn.pressed.connect(func() -> void:
		hide()
		cancelled.emit()
	)


func show_offer(message: String) -> void:
	_label.text = message
	show()


func hide_dialog() -> void:
	hide()
