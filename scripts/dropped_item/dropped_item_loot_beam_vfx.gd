class_name DroppedItemLootBeamVfx
extends Node3D
## Diablo-style loot beam. Параметры — DroppedItemLootBeamSettings (.tres).

const BEAM_SHADER := preload("res://shaders/loot_beam.gdshader")
const GROUND_GLOW_SHADER := preload("res://shaders/loot_ground_glow.gdshader")
const SETTINGS_SCRIPT := preload("res://scripts/dropped_item/dropped_item_loot_beam_settings.gd")

var _settings: Resource
var _beam_mesh: MeshInstance3D
var _ground_glow: MeshInstance3D
var _rise_particles: GPUParticles3D
var _spark_particles: GPUParticles3D
var _beam_light: OmniLight3D
var _beam_material: ShaderMaterial
var _glow_material: ShaderMaterial
var _rise_process: ParticleProcessMaterial
var _spark_process: ParticleProcessMaterial


func _ready() -> void:
	ensure_built()


func configure(settings: Resource) -> void:
	_settings = _resolve_settings(settings)


func ensure_built(settings: Resource = null) -> void:
	_settings = _resolve_settings(settings if settings != null else _settings)
	if _beam_mesh != null:
		return
	_build_beam_column()
	_build_ground_glow()
	_build_particles()
	_build_light()
	_apply_shader_uniforms()


func set_highlight_visible(enabled: bool) -> void:
	visible = enabled


func _resolve_settings(settings: Resource = null) -> Resource:
	if settings != null:
		return settings
	if _settings != null:
		return _settings
	return SETTINGS_SCRIPT.get_default()


func set_rarity_color(color: Color) -> void:
	var cfg := _resolve_settings()
	var beam_tint := Color(color.r, color.g, color.b, cfg.beam_alpha)
	var glow_tint := Color(color.r, color.g, color.b, cfg.ground_glow_alpha)
	if _beam_material != null:
		_beam_material.set_shader_parameter("beam_color", beam_tint)
	if _glow_material != null:
		_glow_material.set_shader_parameter("glow_color", glow_tint)
	if _beam_light != null:
		_beam_light.light_color = color
	if _rise_process != null:
		_rise_process.color = color.lightened(0.25)
	if _spark_process != null:
		_spark_process.color = color


func _apply_shader_uniforms() -> void:
	var cfg := _resolve_settings()
	if _beam_material != null:
		_beam_material.set_shader_parameter("pulse_speed", cfg.pulse_speed)
		_beam_material.set_shader_parameter("scroll_speed", cfg.scroll_speed)
		_beam_material.set_shader_parameter("shimmer_speed", cfg.shimmer_speed)
		_beam_material.set_shader_parameter("noise_strength", cfg.noise_strength)
		_beam_material.set_shader_parameter("core_tightness", cfg.core_tightness)
		_beam_material.set_shader_parameter("beam_falloff", cfg.beam_falloff)
	if _glow_material != null:
		_glow_material.set_shader_parameter("pulse_speed", cfg.ground_pulse_speed)
		_glow_material.set_shader_parameter("ring_sharpness", cfg.ground_ring_sharpness)


func _build_beam_column() -> void:
	var cfg := _resolve_settings()
	_beam_mesh = MeshInstance3D.new()
	_beam_mesh.name = "BeamColumn"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = cfg.beam_bottom_radius_m * cfg.beam_top_radius_ratio
	cylinder.bottom_radius = cfg.beam_bottom_radius_m
	cylinder.height = cfg.beam_height_m
	cylinder.radial_segments = 16
	_beam_mesh.mesh = cylinder
	_beam_mesh.position = Vector3(0.0, cfg.beam_height_m * 0.5, 0.0)
	_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = BEAM_SHADER
	_beam_material.set_shader_parameter("noise_tex", MagicVfxTextures.get_noise())
	_beam_mesh.material_override = _beam_material
	add_child(_beam_mesh)


func _build_ground_glow() -> void:
	var cfg := _resolve_settings()
	_ground_glow = MeshInstance3D.new()
	_ground_glow.name = "GroundGlow"
	var disk := CylinderMesh.new()
	disk.top_radius = cfg.ground_glow_radius_m
	disk.bottom_radius = cfg.ground_glow_radius_m
	disk.height = 0.02
	disk.radial_segments = 24
	_ground_glow.mesh = disk
	_ground_glow.position = Vector3(0.0, 0.015, 0.0)
	_ground_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow_material = ShaderMaterial.new()
	_glow_material.shader = GROUND_GLOW_SHADER
	_ground_glow.material_override = _glow_material
	add_child(_ground_glow)


func _build_particles() -> void:
	var cfg := _resolve_settings()
	_rise_particles = _make_particles(
		"RiseMotes",
		cfg.rise_amount,
		cfg.rise_lifetime_sec,
		cfg.rise_quad_size_m,
		_make_rise_material()
	)
	_rise_particles.position = Vector3(0.0, cfg.rise_position_y_m, 0.0)
	add_child(_rise_particles)

	_spark_particles = _make_particles(
		"Sparks",
		cfg.spark_amount,
		cfg.spark_lifetime_sec,
		cfg.spark_quad_size_m,
		_make_spark_material()
	)
	_spark_particles.position = Vector3(0.0, cfg.spark_position_y_m, 0.0)
	add_child(_spark_particles)


func _build_light() -> void:
	var cfg := _resolve_settings()
	_beam_light = OmniLight3D.new()
	_beam_light.name = "BeamLight"
	_beam_light.light_energy = cfg.light_energy
	_beam_light.omni_range = cfg.light_range_m
	_beam_light.shadow_enabled = false
	_beam_light.position = Vector3(0.0, cfg.light_position_y_m, 0.0)
	add_child(_beam_light)


func _make_particles(
	node_name: String,
	amount: int,
	lifetime: float,
	quad_size_m: float,
	proc: ParticleProcessMaterial
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = maxi(amount, 0)
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.emitting = amount > 0
	particles.local_coords = true
	particles.explosiveness = 0.0
	particles.randomness = 0.35
	particles.process_material = proc
	var quad := QuadMesh.new()
	quad.size = Vector2(quad_size_m, quad_size_m)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad_mat.vertex_color_use_as_albedo = true
	quad.material = quad_mat
	particles.draw_pass_1 = quad
	return particles


func _make_rise_material() -> ParticleProcessMaterial:
	var cfg := _resolve_settings()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = cfg.beam_bottom_radius_m * 1.1
	mat.emission_ring_height = 0.06
	mat.emission_ring_inner_radius = 0.02
	mat.direction = Vector3.UP
	mat.spread = 10.0
	mat.initial_velocity_min = cfg.rise_velocity_min
	mat.initial_velocity_max = cfg.rise_velocity_max
	mat.gravity = Vector3(0.0, 0.15, 0.0)
	mat.damping_min = 0.2
	mat.damping_max = 0.6
	mat.scale_min = cfg.rise_scale_min_m
	mat.scale_max = cfg.rise_scale_max_m
	mat.color = Color(1.0, 0.95, 0.85, 1.0)
	_rise_process = mat
	return mat


func _make_spark_material() -> ParticleProcessMaterial:
	var cfg := _resolve_settings()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = cfg.beam_bottom_radius_m * 1.8
	mat.direction = Vector3.UP
	mat.spread = 22.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0.0, -0.35, 0.0)
	mat.scale_min = cfg.spark_scale_min_m
	mat.scale_max = cfg.spark_scale_max_m
	mat.color = Color(1.0, 1.0, 1.0, 0.9)
	var ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 0.85, 0.4, 0.0))
	ramp.gradient = gradient
	mat.color_ramp = ramp
	_spark_process = mat
	return mat
