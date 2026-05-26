class_name MagicProjectile
extends Area3D
## Магический снаряд: горизонтальный полёт, высота по terrain, попадание через shape-cast.

const CORE_SHADER := preload("res://shaders/magic_comet_core.gdshader")
const RIBBON_SHADER := preload("res://shaders/magic_comet_ribbon.gdshader")
const ICE_CRYSTAL_SHADER := preload("res://shaders/ice_crystal.gdshader")
const BURST_SCENE := preload("res://scenes/combat/magic_hit_burst_vfx.tscn")

const MIN_DIRECTION_LENGTH_SQ := 0.0001
## Terrain / стены (слой world).
const MASK_WORLD_BLOCK := 1
## Манекены, harvestable, враги с bit harvestable (слой 5).
const MASK_DAMAGE_TARGETS := 16

var _settings: MagicProjectileSettings
var _damage_amount: float = 0.0
var _direction_xz: Vector3 = Vector3.FORWARD
var _direction_3d: Vector3 = Vector3.FORWARD
var _speed_mps: float = 0.0
var _source: Node = null
var _traveled_m: float = 0.0
var _alive_sec: float = 0.0
var _hit: bool = false
var _visual_root: Node3D


func launch(
	origin: Vector3,
	direction_xz: Vector3,
	settings: MagicProjectileSettings,
	source: Node,
	damage_amount: float = -1.0
) -> void:
	_settings = settings if settings != null else MagicProjectileSettings.get_default_fire()
	_source = source
	_direction_xz = _horizontal_unit(direction_xz)
	_speed_mps = _settings.speed
	_damage_amount = damage_amount if damage_amount > 0.0 else _settings.damage
	global_position = origin
	if _settings.follow_terrain_height:
		global_position.y = _flight_height_at(global_position.x, global_position.z, origin.y)
		_direction_3d = _horizontal_unit(_direction_xz)
	else:
		_direction_3d = _compute_flight_direction(origin, _direction_xz)
	_align_visuals()
	_build_visuals()
	_setup_collision()
	collision_mask = _settings.collision_mask


static func _horizontal_unit(dir: Vector3) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < MIN_DIRECTION_LENGTH_SQ:
		return Vector3.FORWARD
	return flat.normalized()


func _compute_flight_direction(origin: Vector3, dir_xz: Vector3) -> Vector3:
	var flat := _horizontal_unit(dir_xz)
	var probe_dist := minf(_settings.max_travel_distance_m * 0.9, 26.0)
	var end_xz := origin + flat * probe_dist
	var end_y := origin.y
	if _settings.follow_terrain_height:
		end_y = _flight_height_at(end_xz.x, end_xz.z, origin.y)
	else:
		var ground := TerrainHeightQuery.get_ground_y(self, end_xz.x, end_xz.z, origin.y)
		if not is_nan(ground):
			end_y = maxf(origin.y, ground + _settings.flight_height_above_ground_m)
	var to_end := Vector3(end_xz.x, end_y, end_xz.z) - origin
	if to_end.length_squared() < MIN_DIRECTION_LENGTH_SQ:
		return Vector3(flat.x, 0.12, flat.z).normalized()
	return to_end.normalized()


func _align_visuals() -> void:
	var face_dir := _direction_xz if _settings.follow_terrain_height else _direction_3d
	if face_dir.length_squared() < MIN_DIRECTION_LENGTH_SQ:
		face_dir = _direction_3d
	if face_dir.length_squared() > MIN_DIRECTION_LENGTH_SQ:
		look_at(global_position + face_dir, Vector3.UP)


func _build_visuals() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visuals"
	add_child(_visual_root)
	_add_projectile_light()
	if _settings.visual_style == MagicProjectileSettings.ProjectileVisualStyle.ICE_CRYSTAL:
		_build_ice_crystal_visuals()
	else:
		_build_fire_comet_visuals()


func _add_projectile_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = _settings.core_hot_color
	light.light_energy = _settings.core_light_energy
	light.omni_range = _settings.core_light_range
	light.shadow_enabled = false
	_visual_root.add_child(light)


func _build_fire_comet_visuals() -> void:
	_add_comet_ribbon_trail()
	_add_comet_ember_particles()
	_add_fire_core()


func _build_ice_crystal_visuals() -> void:
	_add_ice_crystal_head()
	_add_ice_trail_shards()
	_add_ice_mist_particles()


func _make_ice_crystal_material(emission_mul: float = 1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ICE_CRYSTAL_SHADER
	mat.set_shader_parameter("crystal_color", _settings.core_color)
	mat.set_shader_parameter("rim_color", _settings.core_hot_color)
	mat.set_shader_parameter("emission_strength", _settings.core_emission * emission_mul)
	return mat


func _make_ice_prism_mesh(length_m: float, radius_m: float) -> CylinderMesh:
	var prism := CylinderMesh.new()
	prism.top_radius = radius_m * 0.2
	prism.bottom_radius = radius_m
	prism.height = length_m
	prism.radial_segments = 6
	prism.rings = 1
	return prism


func _add_ice_crystal_head() -> void:
	var head := MeshInstance3D.new()
	head.name = "IceCrystalHead"
	head.mesh = _make_ice_prism_mesh(_settings.crystal_length_m, _settings.core_radius_m)
	head.material_override = _make_ice_crystal_material(1.15)
	head.rotation_degrees.x = 90.0
	head.position = Vector3(0.0, 0.0, -_settings.core_forward_offset_m - _settings.crystal_length_m * 0.5)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(head)

	var core_glow := MeshInstance3D.new()
	core_glow.name = "IceCrystalCore"
	var inner := CylinderMesh.new()
	inner.top_radius = _settings.core_radius_m * 0.08
	inner.bottom_radius = _settings.core_radius_m * 0.35
	inner.height = _settings.crystal_length_m * 0.65
	inner.radial_segments = 6
	core_glow.mesh = inner
	var glow_mat := _make_ice_crystal_material(1.6)
	glow_mat.set_shader_parameter("facet_contrast", 0.2)
	core_glow.material_override = glow_mat
	core_glow.rotation_degrees.x = 90.0
	core_glow.position = head.position + Vector3(0.0, 0.0, _settings.crystal_length_m * 0.08)
	core_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(core_glow)


func _add_ice_trail_shards() -> void:
	var shard_count := maxi(_settings.crystal_shard_count, 1)
	var tail_span := _settings.tail_length_m
	for i in shard_count:
		var t := float(i + 1) / float(shard_count + 1)
		var shard := MeshInstance3D.new()
		shard.name = "IceShard%d" % i
		var size_scale := lerpf(0.75, 0.22, t)
		shard.mesh = _make_ice_prism_mesh(_settings.crystal_length_m * size_scale * 0.55, _settings.core_radius_m * size_scale)
		shard.material_override = _make_ice_crystal_material(lerpf(0.9, 0.45, t))
		shard.rotation_degrees.x = 90.0
		shard.rotation_degrees.y = float(i % 3) * 22.0
		shard.position = Vector3(0.0, 0.0, tail_span * t + _settings.core_radius_m * 0.1)
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual_root.add_child(shard)


func _add_ice_mist_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "IceMist"
	particles.amount = _settings.ember_particle_count / 2
	particles.lifetime = _settings.trail_lifetime_sec * 0.7
	particles.preprocess = _settings.trail_lifetime_sec
	particles.emitting = true
	particles.local_coords = true
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = _settings.ember_emit_radius_m * 0.6
	material.direction = Vector3(0.0, 0.0, 1.0)
	material.spread = 10.0
	material.initial_velocity_min = 0.2
	material.initial_velocity_max = 0.8
	material.gravity = Vector3.ZERO
	material.scale_min = _settings.ember_scale_min_m * 0.5
	material.scale_max = _settings.ember_scale_max_m * 0.5
	material.color = _settings.trail_mid_color
	particles.process_material = material
	var quad := QuadMesh.new()
	quad.size = Vector2(_settings.ember_quad_size_m * 0.35, _settings.ember_quad_size_m * 0.35)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad_mat.albedo_color = _settings.core_hot_color
	quad_mat.emission_enabled = true
	quad_mat.emission = _settings.core_hot_color
	quad_mat.emission_energy_multiplier = 1.8
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = quad_mat
	particles.draw_pass_1 = quad
	particles.position = Vector3(0.0, 0.0, _settings.tail_emit_offset_forward_m)
	_visual_root.add_child(particles)


func _make_ribbon_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = RIBBON_SHADER
	mat.set_shader_parameter("main_tex", MagicVfxTextures.get_basic())
	mat.set_shader_parameter("noise_tex", MagicVfxTextures.get_noise())
	mat.set_shader_parameter("color_hot", _settings.core_hot_color)
	mat.set_shader_parameter("color_mid", _settings.trail_mid_color)
	mat.set_shader_parameter("color_tail", _settings.trail_color)
	mat.set_shader_parameter("scroll_speed", _settings.tail_scroll_speed)
	mat.set_shader_parameter("noise_strength", _settings.tail_noise_strength)
	mat.set_shader_parameter("emission_strength", _settings.core_emission * _settings.tail_emission_multiplier)
	return mat


func _make_ribbon_mesh() -> RibbonTrailMesh:
	var ribbon := RibbonTrailMesh.new()
	var sections := maxi(_settings.tail_ribbon_sections, 4)
	ribbon.size = _settings.tail_ribbon_width_m
	ribbon.sections = sections
	ribbon.section_length = _settings.tail_length_m / float(sections)
	ribbon.section_segments = 4
	ribbon.shape = RibbonTrailMesh.SHAPE_CROSS
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	ribbon.curve = curve
	ribbon.material = _make_ribbon_material()
	return ribbon


func _add_comet_ribbon_trail() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "CometRibbon"
	particles.amount = _settings.ribbon_particle_count
	particles.lifetime = _settings.trail_lifetime_sec
	particles.preprocess = _settings.trail_lifetime_sec
	particles.emitting = true
	particles.local_coords = true
	particles.trail_enabled = true
	particles.trail_lifetime = _settings.trail_lifetime_sec * _settings.ribbon_trail_lifetime_multiplier
	particles.draw_pass_1 = _make_ribbon_mesh()
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.initial_velocity_min = 0.0
	material.initial_velocity_max = 0.0
	material.gravity = Vector3.ZERO
	material.color = _settings.core_hot_color
	particles.process_material = material
	particles.position = Vector3(0.0, 0.0, _settings.tail_emit_offset_forward_m)
	_visual_root.add_child(particles)


func _add_comet_ember_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "CometEmbers"
	particles.amount = _settings.ember_particle_count
	particles.lifetime = _settings.trail_lifetime_sec * _settings.ember_lifetime_ratio
	particles.preprocess = _settings.trail_lifetime_sec
	particles.emitting = true
	particles.local_coords = true
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = _settings.ember_emit_radius_m
	material.direction = Vector3(0.0, 0.0, 1.0)
	material.spread = 14.0
	material.initial_velocity_min = _settings.ember_speed_min_mps
	material.initial_velocity_max = _settings.ember_speed_max_mps
	material.gravity = Vector3.ZERO
	material.scale_min = _settings.ember_scale_min_m
	material.scale_max = _settings.ember_scale_max_m
	material.color = _settings.core_color
	material.color_ramp = _make_ember_color_ramp()
	particles.process_material = material
	var quad := QuadMesh.new()
	quad.size = Vector2(_settings.ember_quad_size_m, _settings.ember_quad_size_m)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad_mat.albedo_texture = MagicVfxTextures.get_basic()
	quad_mat.emission_enabled = true
	quad_mat.emission = _settings.core_hot_color
	quad_mat.emission_energy_multiplier = _settings.ember_material_emission
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = quad_mat
	particles.draw_pass_1 = quad
	particles.position = Vector3(0.0, 0.0, _settings.ember_emit_offset_forward_m)
	_visual_root.add_child(particles)


static func _make_ember_color_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	gradient.set_color(1, Color(1.0, 0.25, 0.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _add_fire_core() -> void:
	var core := MeshInstance3D.new()
	core.name = "Core"
	var radius := _settings.core_radius_m
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	core.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = CORE_SHADER
	mat.set_shader_parameter("main_tex", MagicVfxTextures.get_basic())
	mat.set_shader_parameter("noise_tex", MagicVfxTextures.get_noise())
	mat.set_shader_parameter("core_color", _settings.core_color)
	mat.set_shader_parameter("core_hot_color", _settings.core_hot_color)
	mat.set_shader_parameter("emission_strength", _settings.core_emission)
	mat.set_shader_parameter("noise_scroll", _settings.noise_scroll_speed)
	mat.set_shader_parameter("pulse_speed", _settings.pulse_speed)
	core.material_override = mat
	core.position = Vector3(0.0, 0.0, -_settings.core_forward_offset_m)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(core)


func _setup_collision() -> void:
	var shape := SphereShape3D.new()
	shape.radius = _settings.collision_radius
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	monitoring = true
	monitorable = false


func _physics_process(delta: float) -> void:
	if _hit:
		return
	_alive_sec += delta
	if _alive_sec >= _settings.max_lifetime_sec:
		_despawn()
		return
	var from := global_position
	var to: Vector3
	var traveled_step: float
	if _settings.follow_terrain_height:
		var flat_step := _direction_xz * _speed_mps * delta
		to = from + flat_step
		to.y = _flight_height_at(to.x, to.z, from.y)
		traveled_step = Vector2(flat_step.x, flat_step.z).length()
	else:
		var step := _direction_3d * _speed_mps * delta
		to = from + step
		traveled_step = step.length()
	var overlap_target := _probe_damage_target_at(to)
	if overlap_target != null:
		var contact := _refine_contact_on_node(from, overlap_target, to)
		_detonate_at_contact(contact, overlap_target)
		return
	var hit := _cast_contact_along_motion(from, to)
	if not hit.is_empty():
		var contact_pos: Vector3 = hit.position as Vector3
		var collider: Object = hit.get("collider")
		if collider is Node:
			_detonate_at_contact(contact_pos, collider as Node)
		else:
			_detonate_at_contact(contact_pos, null)
		return
	global_position = to
	_traveled_m += traveled_step
	_align_visuals()
	if _traveled_m >= _settings.max_travel_distance_m:
		_despawn()


func _flight_height_at(world_x: float, world_z: float, fallback_y: float) -> float:
	var ground := TerrainHeightQuery.get_ground_y(self, world_x, world_z, fallback_y)
	if is_nan(ground):
		return fallback_y
	return ground + _settings.flight_height_above_ground_m


func _sweep_exclude_rids() -> Array[RID]:
	var exclude: Array[RID] = [get_rid()]
	if _source != null and is_instance_valid(_source):
		exclude.append(_source.get_rid())
	return exclude


func _refine_contact_on_node(from: Vector3, node: Node, fallback: Vector3) -> Vector3:
	if node is Node3D:
		var target_pos := (node as Node3D).global_position + Vector3(0.0, 1.2, 0.0)
		var space := get_world_3d().direct_space_state if get_world_3d() != null else null
		if space != null:
			var ray := PhysicsRayQueryParameters3D.create(from, target_pos)
			ray.collision_mask = MASK_WORLD_BLOCK | MASK_DAMAGE_TARGETS
			ray.collide_with_areas = true
			ray.collide_with_bodies = true
			ray.exclude = _sweep_exclude_rids()
			var hit := space.intersect_ray(ray)
			if not hit.is_empty():
				return hit.position as Vector3
	return fallback


func _cast_contact_along_motion(from: Vector3, to: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state if get_world_3d() != null else null
	if space == null:
		return {}
	var motion := to - from
	if motion.length_squared() < 0.000001:
		return {}
	var shape := SphereShape3D.new()
	shape.radius = _settings.collision_radius
	var exclude := _sweep_exclude_rids()
	var sweep := PhysicsShapeQueryParameters3D.new()
	sweep.shape = shape
	sweep.transform = Transform3D(Basis(), from)
	sweep.motion = motion
	sweep.collision_mask = MASK_WORLD_BLOCK | MASK_DAMAGE_TARGETS
	sweep.collide_with_areas = true
	sweep.collide_with_bodies = true
	sweep.exclude = exclude
	var motion_safe: PackedFloat32Array = space.cast_motion(sweep)
	if motion_safe.is_empty():
		return {}
	var safe_fraction: float = motion_safe[0]
	if safe_fraction >= 1.0:
		return {}
	var hit_pos := from + motion * safe_fraction
	var rest := PhysicsShapeQueryParameters3D.new()
	rest.shape = shape
	rest.transform = Transform3D(Basis(), hit_pos)
	rest.collision_mask = MASK_WORLD_BLOCK | MASK_DAMAGE_TARGETS
	rest.collide_with_areas = true
	rest.collide_with_bodies = true
	rest.exclude = exclude
	var info: Dictionary = space.get_rest_info(rest)
	if info.is_empty():
		return {"position": hit_pos}
	info["position"] = hit_pos
	return info


func _probe_damage_target_at(center: Vector3) -> Node:
	var space := get_world_3d().direct_space_state if get_world_3d() != null else null
	if space == null:
		return null
	var shape := SphereShape3D.new()
	shape.radius = _settings.collision_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), center)
	params.collision_mask = MASK_DAMAGE_TARGETS
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.exclude = _sweep_exclude_rids()
	for hit in space.intersect_shape(params, 8):
		var collider: Object = hit.get("collider")
		if collider is Node:
			var target := _resolve_damage_target(collider as Node)
			if target != null:
				return target
	return null


func _on_body_entered(body: Node) -> void:
	if _hit or body == _source:
		return
	_detonate_at_contact(global_position, body)


func _on_area_entered(area: Area3D) -> void:
	if _hit:
		return
	_detonate_at_contact(global_position, area)


func _detonate_at_contact(contact_pos: Vector3, node: Node) -> void:
	if _hit or node == _source:
		return
	if node != null and not _should_stop_on_collision(node):
		return
	_begin_hit_resolution()
	var hit_pos := contact_pos
	if node != null and _resolve_damage_target(node) != null:
		hit_pos = _refine_contact_on_node(global_position, node, contact_pos)
	global_position = hit_pos
	_align_visuals()
	var damage_target := _resolve_damage_target(node) if node != null else null
	if _settings.hit_damage_mode == MagicProjectileSettings.HitDamageMode.AREA:
		call_deferred("_apply_hit_at_position", hit_pos, _settings, damage_target)
	else:
		call_deferred("_apply_hit_at_position", hit_pos, _settings, damage_target)


func _should_stop_on_collision(node: Node) -> bool:
	if node == null:
		return false
	if _resolve_damage_target(node) != null:
		return true
	return node is PhysicsBody3D


func _begin_hit_resolution() -> void:
	_hit = true
	set_deferred("monitoring", false)


func _apply_hit_at_position(
	hit_pos: Vector3,
	cfg: MagicProjectileSettings,
	direct_collider: Node = null
) -> void:
	_stop_trails()
	var targets := _collect_damage_targets(hit_pos, cfg, direct_collider)
	var damage_amount := _damage_amount
	for target in targets:
		if not is_instance_valid(target) or target == _source:
			continue
		target.call("take_damage", damage_amount, _source)
	GameAudio.play_3d(cfg.hit_explosion_sound, hit_pos, cfg.hit_explosion_volume_db)
	_spawn_hit_burst(hit_pos, cfg)
	queue_free()


func _collect_damage_targets(
	hit_pos: Vector3,
	cfg: MagicProjectileSettings,
	direct_collider: Node
) -> Array[Node]:
	if cfg.hit_damage_mode == MagicProjectileSettings.HitDamageMode.AREA:
		var targets := _query_damage_targets_in_sphere(
			hit_pos, cfg.area_damage_radius_m, MASK_DAMAGE_TARGETS
		)
		var direct := _resolve_damage_target(direct_collider)
		if direct != null:
			var seen: Dictionary = {}
			for t in targets:
				seen[t.get_instance_id()] = true
			if not seen.has(direct.get_instance_id()):
				targets.append(direct)
		return targets
	var direct := _resolve_damage_target(direct_collider)
	if direct == null:
		return []
	return [direct]


func _query_damage_targets_in_sphere(
	center: Vector3,
	radius_m: float,
	collision_mask: int
) -> Array[Node]:
	var space := get_world_3d().direct_space_state
	if space == null:
		return []
	var shape := SphereShape3D.new()
	shape.radius = radius_m
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), center)
	params.collision_mask = collision_mask
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var exclude: Array[RID] = []
	if _source != null and is_instance_valid(_source):
		exclude.append(_source.get_rid())
	exclude.append(get_rid())
	params.exclude = exclude
	var targets: Array[Node] = []
	var seen: Dictionary = {}
	for hit in space.intersect_shape(params, 32):
		var collider: Object = hit.get("collider")
		if collider == null:
			continue
		var target := _resolve_damage_target(collider as Node)
		if target == null:
			continue
		var instance_id := target.get_instance_id()
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		targets.append(target)
	return targets


func _stop_trails() -> void:
	if _visual_root == null:
		return
	for child in _visual_root.get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).emitting = false


func _resolve_damage_target(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method("take_damage"):
		return node
	var parent := node.get_parent()
	if parent != null and parent.has_method("take_damage"):
		return parent
	return null


func _spawn_hit_burst(pos: Vector3, cfg: MagicProjectileSettings = null) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var burst := BURST_SCENE.instantiate() as MagicHitBurstVfx
	if burst == null:
		return
	root.add_child(burst)
	burst.play_burst(pos, cfg if cfg != null else _settings)


func _despawn() -> void:
	queue_free()
