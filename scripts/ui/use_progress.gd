class_name UseProgressUI
extends Control

@onready var action_label: Label = $Background/VBoxContainer/ActionLabel
@onready var progress_bar: ProgressBar = $Background/VBoxContainer/ProgressBar

func start_use(item_name: String, use_time: float):
	action_label.text = "Использование: " + item_name
	progress_bar.max_value = use_time
	progress_bar.value = 0
	show()

func update_progress(current_time: float):
	progress_bar.value = current_time

func finish():
	hide()

func cancel():
	hide()
