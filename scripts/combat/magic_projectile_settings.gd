@tool
class_name MagicProjectileSettings
extends Resource
## Параметры магического снаряда. Дистанции — метры, скорость — м/с по горизонтали (XZ).

enum ProjectileVisualStyle {
	FIRE_COMET,
	ICE_CRYSTAL,
}

@export_group("Снаряд")
@export var visual_style: ProjectileVisualStyle = ProjectileVisualStyle.FIRE_COMET
## Горизонтальная скорость (м/с). Не зависит от направления клика.
@export_range(4.0, 40.0, 0.5) var speed: float = 22.0
@export_range(0.5, 8.0, 0.1) var max_lifetime_sec: float = 4.0
## Fallback, если у предмета entity_damage = 0. Обычно урон задаётся на ItemData.
@export_range(0.1, 30.0, 0.5) var damage: float = 12.0
@export_range(0.1, 1.5, 0.05) var collision_radius: float = 0.35
## Мир (terrain) + цели (harvestable / манекены).
@export_flags_3d_physics var collision_mask: int = 17
@export_range(2.0, 60.0, 1.0) var max_travel_distance_m: float = 28.0
## Высота полёта над terrain по XZ (следует холмам).
@export_range(0.2, 4.0, 0.05) var flight_height_above_ground_m: float = 1.15
@export var follow_terrain_height: bool = true

@export_group("Точка выпуска")
@export_range(0.4, 2.5, 0.05) var cast_height_above_feet_m: float = 1.05
@export_range(0.0, 1.0, 0.01) var cast_offset_from_grip_m: float = 0.12
@export_range(0.0, 1.5, 0.01) var cast_offset_from_body_m: float = 0.35
@export_range(0.0, 1.5, 0.01) var spawn_offset_forward_m: float = 0.25

@export_group("Ядро")
@export var core_color: Color = Color(1.0, 0.45, 0.08, 1.0)
@export var core_hot_color: Color = Color(1.0, 0.95, 0.55, 1.0)
@export_range(0.15, 1.2, 0.05) var core_radius_m: float = 0.4
@export_range(1.0, 12.0, 0.1) var core_emission: float = 4.8
@export_range(0.5, 16.0, 0.1) var noise_scroll_speed: float = 6.0
@export_range(1.0, 20.0, 0.1) var pulse_speed: float = 12.0
@export_range(0.5, 8.0, 0.1) var core_light_energy: float = 2.2
@export_range(1.0, 12.0, 0.1) var core_light_range: float = 4.5
@export_range(0.0, 1.0, 0.01) var core_forward_offset_m: float = 0.18

@export_group("Ледяной кристалл (ICE_CRYSTAL)")
@export_range(0.6, 3.5, 0.05) var crystal_length_m: float = 1.35
@export_range(3, 8, 1) var crystal_shard_count: int = 4

@export_group("Хвост кометы")
@export var trail_color: Color = Color(1.0, 0.28, 0.02, 0.75)
@export var trail_mid_color: Color = Color(1.0, 0.38, 0.04, 0.9)
@export_range(0.8, 5.0, 0.05) var tail_length_m: float = 2.2
@export_range(0.6, 3.0, 0.05) var tail_ribbon_width_m: float = 0.55
@export_range(4, 24, 1) var tail_ribbon_sections: int = 14
@export_range(1.0, 16.0, 0.1) var tail_scroll_speed: float = 7.5
@export_range(0.0, 1.0, 0.01) var tail_noise_strength: float = 0.42
@export_range(1.0, 16.0, 0.1) var tail_emission_multiplier: float = 1.25
@export_range(8, 64, 1) var ribbon_particle_count: int = 48
@export_range(0.1, 1.0, 0.02) var trail_lifetime_sec: float = 0.42
@export_range(1.0, 4.0, 0.1) var ribbon_trail_lifetime_multiplier: float = 2.4
@export_range(0.0, 0.5, 0.01) var tail_emit_offset_forward_m: float = 0.05
@export_range(8, 128, 1) var ember_particle_count: int = 64
@export_range(0.0, 1.0, 0.02) var ember_lifetime_ratio: float = 0.85
@export_range(0.0, 0.5, 0.01) var ember_emit_radius_m: float = 0.14
@export_range(0.0, 0.5, 0.01) var ember_emit_offset_forward_m: float = 0.08
@export_range(0.1, 3.0, 0.05) var ember_speed_min_mps: float = 0.4
@export_range(0.1, 4.0, 0.05) var ember_speed_max_mps: float = 2.2
@export_range(0.05, 1.0, 0.01) var ember_scale_min_m: float = 0.14
@export_range(0.05, 1.0, 0.01) var ember_scale_max_m: float = 0.3
@export_range(0.5, 4.0, 0.1) var ember_material_emission: float = 2.5
@export_range(0.1, 0.8, 0.02) var ember_quad_size_m: float = 0.5

@export_group("Звук")
@export var cast_sound: AudioStream
@export_range(-40.0, 10.0, 0.5) var cast_sound_volume_db: float = 0.0
@export var hit_explosion_sound: AudioStream
@export_range(-40.0, 10.0, 0.5) var hit_explosion_volume_db: float = 0.0

@export_group("Каст")
@export_range(6, 48, 1) var cast_spark_particles: int = 18

@export_group("Урон при попадании")
enum HitDamageMode {
	SINGLE_TARGET,
	AREA,
}
## SINGLE_TARGET — только цель столкновения (ледяная стрела и т.п.). AREA — взрыв по радиусу.
@export var hit_damage_mode: HitDamageMode = HitDamageMode.SINGLE_TARGET
@export_range(0.5, 10.0, 0.1) var area_damage_radius_m: float = 2.5

@export_group("Попадание (VFX)")
@export var hit_burst_color: Color = Color(1.0, 0.5, 0.1, 0.9)
@export_range(0.08, 0.5, 0.01) var hit_burst_duration: float = 0.22
@export_range(0.3, 2.0, 0.05) var hit_burst_scale: float = 0.7
@export_range(1.0, 12.0, 0.1) var hit_burst_emission: float = 6.0
@export_range(8, 64, 1) var hit_ember_particles: int = 32


static var _default_fire: MagicProjectileSettings
static var _default_ice: MagicProjectileSettings


static func get_default_fire() -> MagicProjectileSettings:
	if _default_fire == null:
		_default_fire = _load_preset("res://resources/combat/fireball_projectile.tres")
	return _default_fire


static func get_default_ice() -> MagicProjectileSettings:
	if _default_ice == null:
		_default_ice = _load_preset("res://resources/combat/ice_arrow_projectile.tres")
	return _default_ice


static func _load_preset(path: String) -> MagicProjectileSettings:
	if ResourceLoader.exists(path):
		var preset := load(path) as MagicProjectileSettings
		if preset != null:
			return preset
	return MagicProjectileSettings.new()
