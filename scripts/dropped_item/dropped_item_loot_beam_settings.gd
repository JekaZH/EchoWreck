@tool
class_name DroppedItemLootBeamSettings
extends Resource
## Настройки столба и частиц лута. Редактируй .tres в инспекторе.

const DEFAULT_PATH := "res://resources/dropped_item/default_loot_beam_settings.tres"

@export_group("Столб")
@export_range(1.0, 10.0, 0.05) var beam_height_m: float = 4.2
@export_range(0.04, 0.45, 0.01) var beam_bottom_radius_m: float = 0.14
@export_range(0.05, 0.6, 0.05) var beam_top_radius_ratio: float = 0.2
@export_range(0.1, 1.0, 0.01) var beam_alpha: float = 0.62
@export_range(0.5, 3.0, 0.05) var beam_falloff: float = 1.35
@export_range(0.0, 10.0, 0.1) var pulse_speed: float = 2.4
@export_range(0.0, 4.0, 0.05) var scroll_speed: float = 1.1
@export_range(0.0, 12.0, 0.1) var shimmer_speed: float = 5.5
@export_range(0.0, 1.0, 0.01) var noise_strength: float = 0.42
@export_range(0.05, 0.8, 0.01) var core_tightness: float = 0.22

@export_group("Свечение на земле")
@export_range(0.2, 1.5, 0.02) var ground_glow_radius_m: float = 0.55
@export_range(0.1, 1.0, 0.01) var ground_glow_alpha: float = 0.78
@export_range(0.0, 10.0, 0.1) var ground_pulse_speed: float = 3.0
@export_range(0.5, 8.0, 0.1) var ground_ring_sharpness: float = 3.2

@export_group("Свет")
@export_range(0.0, 3.0, 0.05) var light_energy: float = 0.65
@export_range(0.5, 8.0, 0.1) var light_range_m: float = 2.4
@export var light_position_y_m: float = 0.35

@export_group("Частицы — подъём")
@export_range(0, 64, 1) var rise_amount: int = 10
@export_range(0.2, 3.0, 0.05) var rise_lifetime_sec: float = 1.35
@export_range(0.02, 0.35, 0.01) var rise_quad_size_m: float = 0.07
@export_range(0.01, 0.2, 0.005) var rise_scale_min_m: float = 0.03
@export_range(0.02, 0.25, 0.005) var rise_scale_max_m: float = 0.07
@export_range(0.0, 5.0, 0.1) var rise_velocity_min: float = 1.1
@export_range(0.0, 6.0, 0.1) var rise_velocity_max: float = 2.4
@export var rise_position_y_m: float = 0.08

@export_group("Частицы — искры")
@export_range(0, 48, 1) var spark_amount: int = 6
@export_range(0.2, 2.0, 0.05) var spark_lifetime_sec: float = 0.85
@export_range(0.02, 0.3, 0.01) var spark_quad_size_m: float = 0.06
@export_range(0.01, 0.15, 0.005) var spark_scale_min_m: float = 0.02
@export_range(0.02, 0.2, 0.005) var spark_scale_max_m: float = 0.05
@export var spark_position_y_m: float = 0.12

@export_group("Outline предмета")
@export_range(0.01, 0.08, 0.001) var outline_width: float = 0.028


static var _default: DroppedItemLootBeamSettings


static func get_default() -> DroppedItemLootBeamSettings:
	if _default != null:
		return _default
	if ResourceLoader.exists(DEFAULT_PATH):
		_default = load(DEFAULT_PATH) as DroppedItemLootBeamSettings
	if _default == null:
		_default = DroppedItemLootBeamSettings.new()
	return _default
