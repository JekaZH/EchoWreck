class_name PlayerPhysicsSettings
extends Resource
## Гравитация, пол и уклоны (CharacterBody3D). Подходит для terrain и статичных плоскостей.


@export_group("Гравитация")
@export var use_project_gravity: bool = false
@export_range(0.5, 3.0, 0.1) var gravity_multiplier: float = 1.0
@export_range(6.0, 40.0, 0.5) var custom_gravity_mps2: float = 22.0
@export_range(8.0, 80.0, 1.0) var max_fall_speed_mps: float = 40.0
## Небольшая скорость вниз на полу — лучше держит контакт (terrain / move_and_slide).
@export_range(-4.0, 0.0, 0.1) var floor_stick_down_mps: float = -1.5

@export_group("Пол и уклоны")
@export_range(0.05, 1.0, 0.05) var floor_snap_length_m: float = 0.4
@export_range(20.0, 60.0, 1.0) var floor_max_angle_deg: float = 50.0
@export var floor_stop_on_slope: bool = false
@export var slide_along_floor: bool = true


static var _default: PlayerPhysicsSettings


static func get_default() -> PlayerPhysicsSettings:
	if _default == null:
		var path := "res://resources/presets/player/default_player_physics.tres"
		if ResourceLoader.exists(path):
			_default = load(path) as PlayerPhysicsSettings
		if _default == null:
			_default = PlayerPhysicsSettings.new()
	return _default


func get_gravity_mps2() -> float:
	if use_project_gravity:
		var project_g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		return project_g * gravity_multiplier
	return custom_gravity_mps2 * gravity_multiplier
