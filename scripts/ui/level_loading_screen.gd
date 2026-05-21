extends CanvasLayer
class_name LevelLoadingScreen

@onready var _status_label: Label = $Root/Center/Panel/Margin/VBox/StatusLabel
@onready var _progress_bar: ProgressBar = $Root/Center/Panel/Margin/VBox/ProgressBar


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


func show_loading(message: String = "Загрузка уровня...") -> void:
	_ensure_controls()
	if _status_label:
		_status_label.text = message
	if _progress_bar:
		_progress_bar.value = 0.0
	show()


func set_progress(ratio: float) -> void:
	_ensure_controls()
	if _progress_bar:
		_progress_bar.value = clampf(ratio, 0.0, 1.0) * 100.0


func _ensure_controls() -> void:
	if _status_label == null:
		_status_label = get_node_or_null("Root/Center/Panel/Margin/VBox/StatusLabel") as Label
	if _progress_bar == null:
		_progress_bar = get_node_or_null("Root/Center/Panel/Margin/VBox/ProgressBar") as ProgressBar


func hide_loading() -> void:
	hide()
