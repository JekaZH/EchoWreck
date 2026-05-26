@tool
class_name PlayerFootstepSettings
extends Resource

const AudioClipSettings := preload("res://scripts/audio/audio_stream_clip_settings.gd")

## Шаги и звуки взаимодействия игрока.


@export_group("Шаги (ходьба)")
## Настройка обрезки — открой .tres и меняй trim_start_sec / trim_end_sec.
@export var step_clip: AudioClipSettings
## Устаревшее: если step_clip пуст, используется целиком.
@export var step_sound: AudioStream
@export_range(-40.0, 10.0, 0.5) var step_volume_db: float = 0.0
@export_range(0.6, 3.0, 0.05) var step_distance_m: float = 1.45
@export_flags_3d_physics var ground_collision_mask: int = 1
@export_range(0.15, 1.2, 0.05) var ground_check_down_m: float = 0.55
@export_range(0.05, 2.0, 0.05) var min_speed_for_steps_mps: float = 0.25

@export_group("Шаги (бег)")
@export_range(0.35, 1.0, 0.05) var run_step_distance_multiplier: float = 0.62
@export_range(0.8, 1.5, 0.02) var run_pitch_scale: float = 1.15
@export_range(-12.0, 6.0, 0.5) var run_volume_db_offset: float = 0.0

@export_group("Подбор предметов")
@export var pickup_clip: AudioClipSettings
@export_range(-40.0, 10.0, 0.5) var pickup_volume_db: float = 0.0

@export_group("Поверхности (будущее)")
@export var surface_sounds: Array = []


static var _default: PlayerFootstepSettings


static func get_default() -> PlayerFootstepSettings:
	if _default == null:
		var path := "res://resources/audio/default_player_footsteps.tres"
		if ResourceLoader.exists(path):
			_default = load(path) as PlayerFootstepSettings
		if _default == null:
			_default = PlayerFootstepSettings.new()
	return _default


func has_step_audio() -> bool:
	return get_step_clip_for_surface() != null


func get_step_distance_m(is_running: bool) -> float:
	if is_running:
		return step_distance_m * run_step_distance_multiplier
	return step_distance_m


func get_step_clip_for_surface(surface_id: String = "") -> AudioClipSettings:
	for entry in surface_sounds:
		if entry == null or not entry is FootstepSurfaceSound:
			continue
		var surface := entry as FootstepSurfaceSound
		if surface.surface_id == surface_id:
			if surface.step_clip != null and surface.step_clip.has_stream():
				return surface.step_clip
			if surface.step_sound != null:
				return AudioClipSettings.from_stream(surface.step_sound)
	if step_clip != null and step_clip.has_stream():
		return step_clip
	if step_sound != null:
		return AudioClipSettings.from_stream(step_sound)
	return null


func get_volume_db_for_surface(surface_id: String = "", is_running: bool = false) -> float:
	var volume := step_volume_db
	for entry in surface_sounds:
		if entry == null or not entry is FootstepSurfaceSound:
			continue
		var surface := entry as FootstepSurfaceSound
		if surface.surface_id == surface_id:
			volume = surface.volume_db
			break
	if is_running:
		volume += run_volume_db_offset
	return volume


func get_pitch_scale(is_running: bool) -> float:
	if is_running:
		return run_pitch_scale
	return 1.0


## Минимальный интервал между шагами: не чаще дистанции и не чаще длины клипа.
func get_min_step_interval_sec(
	is_running: bool,
	speed_mps: float,
	surface_id: String = ""
) -> float:
	var dist_interval := get_step_distance_m(is_running) / maxf(speed_mps, 1.0)
	var clip := get_step_clip_for_surface(surface_id)
	var clip_interval := 0.0
	if clip != null:
		clip_interval = clip.get_play_length_sec(get_pitch_scale(is_running))
	return maxf(maxf(dist_interval, clip_interval), 0.1)
