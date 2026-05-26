@tool
extends MeshInstance3D
## Полупрозрачный цилиндр в редакторе; в игре скрывается.


func _ready() -> void:
	_update_visibility()


func _enter_tree() -> void:
	_update_visibility()


func _update_visibility() -> void:
	visible = Engine.is_editor_hint()
