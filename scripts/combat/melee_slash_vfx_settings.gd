@tool
class_name MeleeSlashVfxSettings
extends Resource
## Визуал волны удара мечом. Назначается в `ItemData.slash_vfx` или на сцене `SwordSlashVfx`.

@export_group("Позиция дуги")
## Смещение визуала по Y от точки удара (`melee_arc_height` на предмете).
@export var height_offset: float = -0.55

@export_group("Дуга — радиус (доля reach предмета)")
## Ближняя кромка дуги (0 = у ног, 1 = полный reach).
@export_range(0.0, 1.0, 0.01) var arc_inner_reach_ratio: float = 0.14
## Дальняя кромка дуги.
@export_range(0.0, 1.2, 0.01) var arc_outer_reach_ratio: float = 0.95

@export_group("Волна — скорость и диапазон")
@export_range(0.05, 2.0, 0.01) var sweep_duration: float = 0.32
## UV.x: откуда бежит полоса (0 = левый край дуги).
@export_range(0.0, 1.0, 0.01) var progress_start: float = 0.0
## UV.x: куда доходит полоса (>1 — чуть за край).
@export_range(0.0, 1.5, 0.01) var progress_end: float = 1.08
@export_range(0.0, 1.0, 0.01) var fade_duration: float = 0.18
@export var sweep_ease: Tween.EaseType = Tween.EASE_OUT
@export var sweep_trans: Tween.TransitionType = Tween.TRANS_QUAD

@export_group("Шейдер — цвет и форма")
@export var slash_color: Color = Color(0.42, 0.82, 1.0, 0.92)
@export_range(0.02, 0.5, 0.01) var band_width: float = 0.16
@export_range(1.0, 40.0, 0.5) var wave_freq: float = 16.0
@export_range(0.0, 0.3, 0.01) var wave_amp: float = 0.1
@export_range(0.01, 0.3, 0.01) var edge_soft: float = 0.12
@export_range(0.5, 6.0, 0.1) var emission_strength: float = 2.2
@export_range(0.0, 40.0, 0.5) var wave_phase_speed: float = 18.0
@export_range(0.0, 40.0, 0.5) var ripple_phase_speed: float = 22.0

@export_group("Сетка плоскости")
@export_range(8, 80, 1) var subdivide_width: int = 40
@export_range(2, 24, 1) var subdivide_depth: int = 8


static var _default: MeleeSlashVfxSettings


static func get_default() -> MeleeSlashVfxSettings:
	if _default == null:
		_default = load("res://resources/combat/default_melee_slash_vfx.tres") as MeleeSlashVfxSettings
		if _default == null:
			_default = MeleeSlashVfxSettings.new()
	return _default
