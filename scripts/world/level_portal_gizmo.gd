@tool
class_name LevelPortalGizmo
extends RefCounted

## Общие материалы/меши для отображения зон и точек в редакторе и (опционально) в игре.


static func make_unshaded_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	return mat


static func ensure_box_mesh(node: MeshInstance3D, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = make_unshaded_material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func ensure_spawn_mesh(node: MeshInstance3D, color: Color) -> void:
	# Диск у ног + «стрелка» вперёд по -Z (как у Marker3D).
	var parent := node.get_parent()
	if parent == null:
		return
	for c in node.get_children():
		node.remove_child(c)
		c.free()

	var disk := MeshInstance3D.new()
	disk.name = "Disk"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 0.06
	disk.mesh = cyl
	disk.material_override = make_unshaded_material(color)
	disk.position = Vector3(0, 0.03, 0)
	node.add_child(disk)

	var arrow := MeshInstance3D.new()
	arrow.name = "Arrow"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.5, 0.7)
	arrow.mesh = prism
	arrow.material_override = make_unshaded_material(color.lightened(0.15))
	arrow.position = Vector3(0, 0.2, -0.55)
	arrow.rotation_degrees = Vector3(90, 0, 0)
	node.add_child(arrow)


static func ensure_label(parent: Node3D, text: String, offset: Vector3, color: Color) -> Label3D:
	var label := parent.get_node_or_null("PortalLabel") as Label3D
	if label == null:
		label = Label3D.new()
		label.name = "PortalLabel"
		parent.add_child(label)
	label.text = text
	label.position = offset
	label.font_size = 28
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_modulate = Color.BLACK
	label.render_priority = 10
	return label
