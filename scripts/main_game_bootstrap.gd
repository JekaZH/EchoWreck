extends Node3D

## Стабильный ключ для LevelWorldCache / сейва (путь .tscn). Пусто = scene_file_path.
@export_file("*.tscn") var level_save_key: String = ""


func _ready() -> void:
	var was_save_load := SaveManager.has_pending_save_data()
	SaveManager.apply_pending_to_game(self)
	if was_save_load:
		await _finish_loading_if_needed()
		return
	LevelTravelManager.apply_travel_player_snapshot(self)
	LevelTravelManager.apply_arrival_to_player(self)
	LevelWorldCache.apply_level(self)
	await _finish_loading_if_needed()


func _finish_loading_if_needed() -> void:
	if LevelTravelManager.is_level_transition_active():
		await LevelTravelManager.finish_level_transition()
