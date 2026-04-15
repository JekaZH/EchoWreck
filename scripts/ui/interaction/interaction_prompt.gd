class_name InteractionPrompt
extends Control

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/Margin/Label

func set_text(t: String) -> void:
	label.text = t

func set_screen_position(p: Vector2) -> void:
	global_position = p

func set_visible_prompt(v: bool) -> void:
	visible = v
