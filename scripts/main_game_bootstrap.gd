extends Node3D

func _ready() -> void:
	var was_save_load := SaveManager.has_pending_save_data()
	SaveManager.apply_pending_to_game(self)
	if was_save_load:
		return
	LevelTravelManager.apply_travel_player_snapshot(self)
	LevelTravelManager.apply_arrival_to_player(self)
	LevelWorldCache.apply_level(self)
