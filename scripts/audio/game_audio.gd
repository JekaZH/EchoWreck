class_name GameAudio
extends RefCounted
## Воспроизведение одноразовых звуков в мире (3D) или UI (2D).


static func play_3d(
	stream: AudioStream,
	world_position: Vector3,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> void:
	if stream == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	tree.current_scene.add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()


static func play_2d(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	tree.root.add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()
