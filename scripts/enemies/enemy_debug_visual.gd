class_name EnemyDebugVisual
extends Node3D
## Тестовые кольца агро/атаки и стрелка направления (только редактор/отладка).

@export var enabled: bool = true
@export var aggro_color: Color = Color(1.0, 0.45, 0.1, 0.28)
@export var attack_color: Color = Color(1.0, 0.85, 0.15, 0.38)
@export var attack_windup_color: Color = Color(1.0, 0.15, 0.15, 0.55)
@export var facing_color: Color = Color(0.35, 0.75, 1.0, 0.9)

var _aggro_ring: MeshInstance3D
var _attack_ring: MeshInstance3D
var _facing_arrow: MeshInstance3D
var _attack_mat: StandardMaterial3D


func setup_from_definition(definition: EnemyDefinition) -> void:
	if not enabled or definition == null:
		visible = false
		return
	visible = true
	_ensure_meshes()
	_resize_ring(_aggro_ring, definition.aggro_range)
	_resize_ring(_attack_ring, definition.attack_range)
	_place_facing_arrow(definition.attack_range)


func refresh(state: EnemyBody.State, is_attack_windup: bool) -> void:
	if not enabled or not visible:
		return
	if _attack_mat:
		_attack_mat.albedo_color = attack_windup_color if is_attack_windup else attack_color
		_attack_mat.emission = attack_windup_color if is_attack_windup else attack_color
		_attack_mat.emission_enabled = is_attack_windup
	if _facing_arrow:
		_facing_arrow.rotation.y = 0.0


func _ensure_meshes() -> void:
	if _aggro_ring != null:
		return
	_aggro_ring = _create_ring_mesh("AggroRing", aggro_color)
	_attack_ring = _create_ring_mesh("AttackRing", attack_color)
	_attack_mat = _attack_ring.material_override as StandardMaterial3D
	_facing_arrow = _create_facing_arrow()
	add_child(_aggro_ring)
	add_child(_attack_ring)
	add_child(_facing_arrow)


func _create_ring_mesh(mesh_name: String, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = mesh_name
	var cyl := CylinderMesh.new()
	cyl.height = 0.05
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	mesh_node.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_node.material_override = mat
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_node


func _resize_ring(ring: MeshInstance3D, radius: float) -> void:
	if ring == null:
		return
	ring.scale = Vector3(radius, 1.0, radius)
	ring.position.y = 0.03


func _create_facing_arrow() -> MeshInstance3D:
	var arrow := MeshInstance3D.new()
	arrow.name = "FacingArrow"
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.06, 0.7)
	arrow.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = facing_color
	mat.emission_enabled = true
	mat.emission = facing_color
	mat.emission_energy_multiplier = 1.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow.material_override = mat
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return arrow


func _place_facing_arrow(attack_range: float) -> void:
	if _facing_arrow == null:
		return
	var dist := maxf(attack_range * 0.55, 0.45)
	_facing_arrow.position = Vector3(0.0, 0.12, -dist)
	_facing_arrow.rotation.y = PI
