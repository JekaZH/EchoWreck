# isometric_camera.gd
class_name IsometricCamera
extends Camera3D

@export var target: Node3D
@export var follow_speed: float = 7.0
@export var offset: Vector3 = Vector3(0, 4.5, 13.0)   # ← подкрути эти значения

func _ready() -> void:
	current = true
	rotation_degrees = Vector3(-50, 45, 0)   # классический isometric угол

func _process(delta: float) -> void:
	if target:
		var desired_pos = target.global_position + offset
		global_position = global_position.lerp(desired_pos, follow_speed * delta)
