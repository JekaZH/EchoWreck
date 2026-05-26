@tool
class_name FootstepSurfaceSound
extends Resource

const AudioClipSettings := preload("res://scripts/audio/audio_stream_clip_settings.gd")

## Звук шага для типа поверхности (трава, камень, дерево…).

@export var surface_id: String = "default"
@export var step_clip: AudioClipSettings
@export var step_sound: AudioStream
@export_range(-40.0, 10.0, 0.5) var volume_db: float = 0.0
