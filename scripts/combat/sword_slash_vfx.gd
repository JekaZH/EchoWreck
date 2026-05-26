@tool
class_name SwordSlashVfx
extends Node3D
## Волна удара мечом. Параметры — `MeleeSlashVfxSettings` (ресурс в инспекторе или из `ItemData`).

const SHADER := preload("res://shaders/sword_slash.gdshader")

## Для превью в редакторе на сцене `sword_slash_vfx.tscn`.
@export var editor_settings: MeleeSlashVfxSettings

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _settings: MeleeSlashVfxSettings
var _base_alpha: float = 0.92


func play(
	origin: Vector3,
	forward: Vector3,
	reach: float,
	arc_angle_deg: float,
	settings: MeleeSlashVfxSettings = null
) -> void:
	if forward.length_squared() < 0.0001:
		queue_free()
		return
	_settings = settings if settings != null else MeleeSlashVfxSettings.get_default()
	forward = forward.normalized()
	_build_mesh(reach, arc_angle_deg, _settings)
	_align_to_forward(origin, forward, _settings)
	_animate_sweep(_settings)


func _build_mesh(reach: float, arc_angle_deg: float, cfg: MeleeSlashVfxSettings) -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "SlashWave"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	plane.subdivide_width = cfg.subdivide_width
	plane.subdivide_depth = cfg.subdivide_depth
	_mesh.mesh = plane
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_apply_shader_params(cfg, reach, arc_angle_deg)
	_mesh.material_override = _material
	add_child(_mesh)


func _apply_shader_params(cfg: MeleeSlashVfxSettings, reach: float, arc_angle_deg: float) -> void:
	_base_alpha = cfg.slash_color.a
	_material.set_shader_parameter("slash_color", cfg.slash_color)
	_material.set_shader_parameter("progress", cfg.progress_start)
	_material.set_shader_parameter("band_width", cfg.band_width)
	_material.set_shader_parameter("wave_freq", cfg.wave_freq)
	_material.set_shader_parameter("wave_amp", cfg.wave_amp)
	_material.set_shader_parameter("edge_soft", cfg.edge_soft)
	_material.set_shader_parameter("reach", reach)
	_material.set_shader_parameter("arc_half_rad", deg_to_rad(arc_angle_deg) * 0.5)
	_material.set_shader_parameter("arc_inner_ratio", cfg.arc_inner_reach_ratio)
	_material.set_shader_parameter("arc_outer_ratio", cfg.arc_outer_reach_ratio)
	_material.set_shader_parameter("emission_strength", cfg.emission_strength)
	_material.set_shader_parameter("wave_phase_speed", cfg.wave_phase_speed)
	_material.set_shader_parameter("ripple_phase_speed", cfg.ripple_phase_speed)


func _align_to_forward(origin: Vector3, forward: Vector3, cfg: MeleeSlashVfxSettings) -> void:
	global_position = origin + Vector3(0.0, cfg.height_offset, 0.0)
	rotation.y = atan2(forward.x, forward.z)


func _animate_sweep(cfg: MeleeSlashVfxSettings) -> void:
	if _material == null:
		queue_free()
		return
	var tween := create_tween()
	tween.set_ease(cfg.sweep_ease)
	tween.set_trans(cfg.sweep_trans)
	tween.tween_method(_set_progress, cfg.progress_start, cfg.progress_end, cfg.sweep_duration)
	tween.chain().tween_method(_fade_out, 1.0, 0.0, cfg.fade_duration)
	tween.chain().tween_callback(queue_free)


func _set_progress(value: float) -> void:
	if _material:
		_material.set_shader_parameter("progress", value)


func _fade_out(multiplier: float) -> void:
	if _material == null:
		return
	var c: Color = _material.get_shader_parameter("slash_color")
	c.a = _base_alpha * multiplier
	_material.set_shader_parameter("slash_color", c)
