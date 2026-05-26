extends Node3D

## Стабильный ключ для LevelWorldCache / сейва (путь .tscn). Пусто = scene_file_path.
@export_file("*.tscn") var level_save_key: String = ""


func _ready() -> void:
	var was_save_load := SaveManager.has_pending_save_data()
	SaveManager.apply_pending_to_game(self)
	if was_save_load:
		await _finish_loading_if_needed()
		_bind_play_session(was_save_load)
		return
	LevelTravelManager.apply_travel_player_snapshot(self)
	LevelTravelManager.apply_arrival_to_player(self)
	if TerrainHeightQuery.find_terrain(self) != null:
		await TerrainHeightQuery.when_terrain_ready(self)
		await _snap_player_to_terrain()
	LevelWorldCache.apply_level(self)
	if TerrainHeightQuery.find_terrain(self) != null:
		await TerrainHeightQuery.when_terrain_ready(self)
		await _resnap_world_objects()
		await _snap_player_to_terrain()
	await _finish_loading_if_needed()
	_bind_play_session(was_save_load)
	await _run_post_travel_autosave_if_needed()


func _run_post_travel_autosave_if_needed() -> void:
	if not LevelTravelManager.consume_post_travel_autosave():
		return
	var settings := SaveManager.get_settings()
	if not settings.autosave_enabled or not settings.autosave_on_level_transition:
		return
	await SaveManager.autosave_game()


func _snap_player_to_terrain() -> void:
	var player := get_node_or_null("Player") as Node3D
	if player:
		await TerrainHeightQuery.snap_node_to_ground_async(player, 0.05)


func _resnap_world_objects() -> void:
	var world := get_node_or_null("World")
	if world == null:
		return
	var setup := world.get_node_or_null("WorldSceneSetup")
	if setup and setup.has_method("_run_setup"):
		await setup._run_setup()


func _bind_play_session(was_save_load: bool) -> void:
	var player := get_node_or_null("Player") as Player
	if player:
		SaveManager.bind_gameplay_session(player)
	if was_save_load:
		SaveManager.clear_unsaved_changes()
	elif SaveManager.consume_mark_dirty_on_next_boot():
		SaveManager.mark_unsaved_changes()


func _finish_loading_if_needed() -> void:
	if LevelTravelManager.is_level_transition_active():
		await LevelTravelManager.finish_level_transition()
