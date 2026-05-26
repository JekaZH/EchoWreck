class_name MagicHitBurstVfx
extends Node3D
## Короткий взрыв при попадании (AAA: вспышка + искры, быстро гаснет).


func play_burst(pos: Vector3, settings: MagicProjectileSettings) -> void:
	global_position = pos
	var cfg := settings if settings != null else MagicProjectileSettings.get_default_fire()
	var life := cfg.hit_burst_duration
	_spawn_flash(cfg, life)
	_spawn_burst_particles(cfg)
	var tree := get_tree()
	if tree:
		tree.create_timer(life + 0.08).timeout.connect(queue_free, CONNECT_ONE_SHOT)
	else:
		queue_free()


func _spawn_flash(cfg: MagicProjectileSettings, life: float) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = cfg.hit_burst_scale * 0.45
	sphere.height = cfg.hit_burst_scale * 0.9
	flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = cfg.core_hot_color
	mat.emission_enabled = true
	mat.emission = cfg.hit_burst_color
	mat.emission_energy_multiplier = cfg.hit_burst_emission
	flash.material_override = mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(2.6, 2.6, 2.6), life * 0.55)
	tween.tween_property(mat, "albedo_color:a", 0.0, life * 0.65)


func _spawn_burst_particles(cfg: MagicProjectileSettings) -> void:
	var burst := GPUParticles3D.new()
	burst.amount = cfg.hit_ember_particles
	burst.lifetime = cfg.hit_burst_duration * 0.85
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = cfg.hit_burst_scale * 0.4
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.08
	pm.scale_max = 0.28
	pm.color = cfg.core_hot_color
	burst.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	burst.draw_pass_1 = quad
	add_child(burst)

	var smoke := GPUParticles3D.new()
	smoke.amount = 12
	smoke.lifetime = cfg.hit_burst_duration * 0.7
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.emitting = true
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = cfg.hit_burst_scale * 0.25
	sm.direction = Vector3(0, 1, 0)
	sm.spread = 70.0
	sm.initial_velocity_min = 0.8
	sm.initial_velocity_max = 2.5
	sm.gravity = Vector3(0, 1.5, 0)
	sm.scale_min = 0.25
	sm.scale_max = 0.55
	var c := cfg.trail_color
	c.a = 0.25
	sm.color = c
	smoke.process_material = sm
	var sm_quad := QuadMesh.new()
	sm_quad.size = Vector2(0.35, 0.35)
	smoke.draw_pass_1 = sm_quad
	add_child(smoke)
