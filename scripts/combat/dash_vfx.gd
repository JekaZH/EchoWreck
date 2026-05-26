class_name DashVfx
extends Node3D
## След рывка: «призраки» вдоль траектории телепорта.

const GHOST_SHADER := preload("res://shaders/dash_ghost.gdshader")


static func play(from_pos: Vector3, to_pos: Vector3, settings: PlayerDashSettings) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var cfg := settings if settings != null else PlayerDashSettings.get_default()
	var vfx := DashVfx.new()
	vfx.name = "DashVfx"
	tree.current_scene.add_child(vfx)
	vfx._spawn_ghosts(from_pos, to_pos, cfg)


func _spawn_ghosts(from_pos: Vector3, to_pos: Vector3, cfg: PlayerDashSettings) -> void:
	var delta := to_pos - from_pos
	var dist := delta.length()
	if dist < 0.05:
		queue_free()
		return
	var forward := delta / dist
	var count := maxi(cfg.ghost_count, 2)
	for i in count:
		var t := float(i) / float(count - 1)
		var pos := from_pos.lerp(to_pos, t)
		pos.y += 0.85
		_spawn_one_ghost(pos, forward, cfg, float(i) * cfg.ghost_stagger_sec)
	var total := cfg.ghost_fade_sec + float(count) * cfg.ghost_stagger_sec + 0.05
	await get_tree().create_timer(total).timeout
	queue_free()


func _spawn_one_ghost(pos: Vector3, forward: Vector3, cfg: PlayerDashSettings, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self):
		return
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(cfg.ghost_width, cfg.ghost_width * 1.35)
	plane.orientation = PlaneMesh.FACE_Z
	mesh_inst.mesh = plane
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = GHOST_SHADER
	mat.set_shader_parameter("ghost_color", cfg.trail_color)
	mat.set_shader_parameter("emission_strength", cfg.emission_strength)
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	mesh_inst.global_position = pos
	if forward.length_squared() > 0.0001:
		mesh_inst.look_at(pos + forward, Vector3.UP)
	var tween := create_tween()
	tween.tween_method(
		func(m: float) -> void:
			if mat:
				var c := cfg.trail_color.lerp(cfg.trail_color_end, 1.0 - m)
				mat.set_shader_parameter("ghost_color", c),
		1.0,
		0.0,
		cfg.ghost_fade_sec
	)
	tween.tween_callback(mesh_inst.queue_free)
