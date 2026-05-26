@tool
class_name PlayerDashSettings
extends Resource
## Настройки рывка (dash) игрока — ресурс в инспекторе на Player.

@export_group("Рывок")
@export_range(1.0, 12.0, 0.1) var distance: float = 4.5
@export_range(0.2, 3.0, 0.05) var cooldown_sec: float = 0.85
@export_range(0.0, 50.0, 1.0) var energy_cost: float = 8.0
@export_range(0.05, 0.4, 0.01) var movement_lock_sec: float = 0.12
## Маска слоёв для проверки стены (обычно мир = 1).
@export_flags_3d_physics var collision_mask: int = 1
@export_range(0.2, 1.5, 0.05) var wall_stop_padding: float = 0.45

@export_group("Высота (земля)")
## Луч вниз ищет пол с этими слоями (обычно земля = 1).
@export_flags_3d_physics var ground_collision_mask: int = 1
@export_range(0.0, 1.5, 0.05) var max_step_up_m: float = 0.35
@export_range(0.5, 6.0, 0.1) var max_drop_m: float = 3.0
@export_range(1.0, 6.0, 0.1) var ground_probe_up_m: float = 2.5
@export_range(1.0, 8.0, 0.1) var ground_probe_down_m: float = 4.0
@export_range(0.4, 1.0, 0.05) var floor_normal_min_y: float = 0.6

@export_group("Визуал рывка")
@export var trail_color: Color = Color(0.55, 0.85, 1.0, 0.75)
@export var trail_color_end: Color = Color(0.2, 0.5, 1.0, 0.0)
@export_range(2, 12, 1) var ghost_count: int = 6
@export_range(0.08, 0.5, 0.01) var ghost_stagger_sec: float = 0.025
@export_range(0.15, 0.8, 0.01) var ghost_fade_sec: float = 0.35
@export_range(0.4, 2.0, 0.05) var ghost_width: float = 0.9
@export_range(0.5, 4.0, 0.1) var emission_strength: float = 2.4


static var _default: PlayerDashSettings


static func get_default() -> PlayerDashSettings:
	if _default == null:
		var path := "res://resources/combat/default_player_dash.tres"
		if ResourceLoader.exists(path):
			_default = load(path) as PlayerDashSettings
		if _default == null:
			_default = PlayerDashSettings.new()
	return _default
