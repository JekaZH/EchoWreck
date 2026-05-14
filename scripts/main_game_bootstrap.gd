extends Node3D

func _ready() -> void:
	SaveManager.apply_pending_to_game(self)
