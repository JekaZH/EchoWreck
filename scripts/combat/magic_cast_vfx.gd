class_name MagicCastVfx
extends Node3D
## Вспышка при выпуске снаряда (без кругов/колец на персонаже).


static func play_shoot(origin: Vector3, forward: Vector3, settings: MagicProjectileSettings) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var node := MagicCastVfx.new()
	tree.current_scene.add_child(node)
	node._run_shoot(origin, forward, settings)


func _run_shoot(origin: Vector3, forward: Vector3, settings: MagicProjectileSettings) -> void:
	var cfg := settings if settings != null else MagicProjectileSettings.get_default_fire()
	var fwd := forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	global_position = origin
	look_at(global_position + fwd, Vector3.UP)
	_spawn_muzzle_sparks(cfg, fwd)
	await get_tree().create_timer(0.25).timeout
	queue_free()


func _spawn_muzzle_sparks(cfg: MagicProjectileSettings, fwd: Vector3) -> void:
	var sparks := GPUParticles3D.new()
	sparks.amount = cfg.cast_spark_particles
	sparks.lifetime = 0.22
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 22.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 0.05
	pm.scale_max = 0.16
	pm.color = cfg.core_hot_color
	sparks.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	sparks.draw_pass_1 = quad
	add_child(sparks)
