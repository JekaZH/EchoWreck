extends Control

signal back_pressed


func _on_back() -> void:
	back_pressed.emit()
