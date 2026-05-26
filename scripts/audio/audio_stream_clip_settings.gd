@tool
class_name AudioStreamClipSettings
extends Resource
## Обрезка и воспроизведение звука. Настраивается в инспекторе на .tres (шаги, подбор и т.д.).

const META_PLAYBACK_TOKEN := &"audio_clip_playback_token"


@export var stream: AudioStream

@export_group("Обрезка")
## С какой секунды начать (отрезать тишину в начале).
@export_range(0.0, 30.0, 0.01, "suffix:с") var trim_start_sec: float = 0.0
## Сколько секунд отрезать с конца файла (0 = играть до конца).
@export_range(0.0, 30.0, 0.01, "suffix:с") var trim_end_sec: float = 0.0


func has_stream() -> bool:
	return stream != null


func get_stream_length_sec() -> float:
	if stream == null:
		return 0.0
	return stream.get_length()


func get_play_length_sec(pitch_scale: float = 1.0) -> float:
	var total := get_stream_length_sec()
	var length := total - trim_start_sec - trim_end_sec
	length = maxf(length, 0.01)
	return length / maxf(pitch_scale, 0.01)


func play_on(
	player: AudioStreamPlayer3D,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	stop_after_trim: bool = true
) -> void:
	if stream == null or player == null:
		return
	var token := _bump_playback_token(player)
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play(trim_start_sec)
	if stop_after_trim and _needs_trim_stop():
		var tree := player.get_tree()
		if tree == null:
			return
		var play_len := get_play_length_sec(pitch_scale)
		tree.create_timer(play_len).timeout.connect(
			func() -> void:
				if not is_instance_valid(player):
					return
				if _get_playback_token(player) != token:
					return
				if player.playing:
					player.stop(),
			CONNECT_ONE_SHOT
		)


func _needs_trim_stop() -> bool:
	return trim_end_sec > 0.001


static func _bump_playback_token(player: Node) -> int:
	var token: int = int(player.get_meta(META_PLAYBACK_TOKEN, 0)) + 1
	player.set_meta(META_PLAYBACK_TOKEN, token)
	return token


static func _get_playback_token(player: Node) -> int:
	return int(player.get_meta(META_PLAYBACK_TOKEN, 0))


static func from_stream(source: AudioStream) -> AudioStreamClipSettings:
	var clip := AudioStreamClipSettings.new()
	clip.stream = source
	return clip
