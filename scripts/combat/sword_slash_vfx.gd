class_name SwordSlashVfx
extends Node3D
## Волна удара мечом: горизонтальная дуга перед игроком, волна бежит слева направо.

const DURATION := 0.32
const SHADER := preload("res://shaders/sword_slash.gdshader")

var _mesh: MeshInstance3D
var _material: ShaderMaterial


func play(origin: Vector3, forward: Vector3, reach: float, arc_angle_deg: float) -> void:
	if forward.length_squared() < 0.0001:
		queue_free()
		return
	forward = forward.normalized()
	_build_mesh(reach, arc_angle_deg)
	_align_to_forward(origin, forward)
	_animate_sweep()


func _build_mesh(reach: float, arc_angle_deg: float) -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "SlashWave"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	plane.subdivide_width = 40
	plane.subdivide_depth = 8
	_mesh.mesh = plane
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("slash_color", Color(0.42, 0.82, 1.0, 0.92))
	_material.set_shader_parameter("progress", 0.0)
	_material.set_shader_parameter("band_width", 0.16)
	_material.set_shader_parameter("wave_freq", 16.0)
	_material.set_shader_parameter("wave_amp", 0.1)
	_material.set_shader_parameter("reach", reach)
	_material.set_shader_parameter("arc_half_rad", deg_to_rad(arc_angle_deg) * 0.5)
	_mesh.material_override = _material
	add_child(_mesh)


func _align_to_forward(origin: Vector3, forward: Vector3) -> void:
	# Немного ниже точки удара — дуга у земли/пояса, не за спиной.
	global_position = origin + Vector3(0.0, -0.55, 0.0)
	rotation.y = atan2(forward.x, forward.z)


func _animate_sweep() -> void:
	if _material == null:
		queue_free()
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_set_progress, 0.0, 1.08, DURATION)
	tween.chain().tween_method(_fade_out, 1.0, 0.0, 0.18)
	tween.chain().tween_callback(queue_free)


func _set_progress(value: float) -> void:
	if _material:
		_material.set_shader_parameter("progress", value)


func _fade_out(multiplier: float) -> void:
	if _material:
		var c: Color = _material.get_shader_parameter("slash_color")
		c.a = 0.92 * multiplier
		_material.set_shader_parameter("slash_color", c)
