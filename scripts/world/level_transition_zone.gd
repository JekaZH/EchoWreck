@tool
class_name LevelTransitionZone
extends Node3D

@export_group("Куда ведёт переход")
@export var target_level: PackedScene: set = _set_target_level
@export_file("*.tscn") var target_level_path: String = ""
@export var level_registry: LevelRegistry
@export var target_level_id: String = ""

## Id маркера на **целевом** уровне (`LevelSpawnPoint.portal_id`).
@export var arrival_portal_id: String = "default"

var target_portal_id: String:
	set(value):
		if not value.is_empty():
			arrival_portal_id = value
	get:
		return arrival_portal_id

@export_group("UI")
@export var zone_display_name: String = "Новая зона"
@export var require_confirmation: bool = true
@export var travel_immediately: bool = false

@export_group("Область (видно зелёным боксом)")
## Тяните узел **LevelTransitionZone** инструментом Move (W) в 3D. Размер бокса — здесь.
@export var zone_size: Vector3 = Vector3(3.0, 2.5, 3.0): set = _set_zone_size

@export_group("Цвет в редакторе")
@export var gizmo_color: Color = Color(0.15, 0.95, 0.35, 0.45): set = _set_gizmo_color
@export var hide_gizmo_in_game: bool = true


func _set_target_level(scene: PackedScene) -> void:
	target_level = scene
	if scene != null:
		target_level_path = scene.resource_path
	_update_editor_visuals()


func _set_zone_size(size: Vector3) -> void:
	zone_size = size.max(Vector3(0.5, 0.5, 0.5))
	_update_editor_visuals()


func _set_gizmo_color(c: Color) -> void:
	gizmo_color = c
	_update_editor_visuals()


func _ready() -> void:
	add_to_group("level_transition_zone")
	var area := _get_trigger_area()
	if area:
		if not area.body_entered.is_connected(_on_body_entered):
			area.body_entered.connect(_on_body_entered)
		if not area.body_exited.is_connected(_on_body_exited):
			area.body_exited.connect(_on_body_exited)
		area.monitoring = true
	_update_editor_visuals()
	_apply_runtime_visibility()


func _enter_tree() -> void:
	_update_editor_visuals()
	_apply_runtime_visibility()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_update_editor_visuals()


func _apply_runtime_visibility() -> void:
	var show_mesh := Engine.is_editor_hint() or not hide_gizmo_in_game
	for n in ["EditorZoneMesh", "EditorLabel"]:
		var node := get_node_or_null(n) as Node3D
		if node:
			node.visible = show_mesh


func _get_trigger_area() -> Area3D:
	return get_node_or_null("TriggerArea") as Area3D


func _update_editor_visuals() -> void:
	if not is_inside_tree():
		return

	var mesh_inst := get_node_or_null("EditorZoneMesh") as MeshInstance3D
	if mesh_inst:
		var box := mesh_inst.mesh as BoxMesh
		if box == null:
			box = BoxMesh.new()
			mesh_inst.mesh = box
		box.size = zone_size
		mesh_inst.position = Vector3(0.0, zone_size.y * 0.5, 0.0)
		var mat := mesh_inst.material_override as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_inst.material_override = mat
		mat.albedo_color = gizmo_color

	var col := get_node_or_null("TriggerArea/CollisionShape3D") as CollisionShape3D
	if col:
		var shape := col.shape as BoxShape3D
		if shape == null:
			shape = BoxShape3D.new()
			col.shape = shape
		shape.size = zone_size
		col.position = Vector3(0.0, zone_size.y * 0.5, 0.0)

	var label := get_node_or_null("EditorLabel") as Label3D
	if label:
		var path_hint := get_resolved_level_path()
		var short_path := path_hint.get_file() if not path_hint.is_empty() else "— сцена не задана —"
		label.text = "ПЕРЕХОД: %s\n→ %s\nспавн: %s" % [zone_display_name, short_path, arrival_portal_id]
		label.position = Vector3(0.0, zone_size.y + 0.85, 0.0)
		label.modulate = gizmo_color.lightened(0.35)


func get_resolved_level_path() -> String:
	if target_level != null and not target_level.resource_path.is_empty():
		return target_level.resource_path
	if not target_level_path.is_empty():
		return target_level_path
	if level_registry != null and not target_level_id.is_empty():
		return level_registry.get_scene_path(target_level_id)
	return ""


func get_arrival_portal_id() -> String:
	var pid := arrival_portal_id.strip_edges()
	if pid.is_empty():
		pid = target_portal_id.strip_edges()
	if pid.is_empty():
		return "default"
	return pid


func _on_body_entered(body: Node) -> void:
	if Engine.is_editor_hint():
		return
	if not body.is_in_group("player"):
		return
	if get_resolved_level_path().is_empty():
		push_warning("LevelTransitionZone '%s': не задан целевой уровень" % name)
		return
	if travel_immediately and not require_confirmation:
		LevelTravelManager.commit_travel(self)
		return
	LevelTravelManager.offer_travel(self)


func _on_body_exited(body: Node) -> void:
	if Engine.is_editor_hint():
		return
	if body.is_in_group("player"):
		LevelTravelManager.cancel_offer(self)


func get_prompt_text() -> String:
	if zone_display_name.is_empty():
		return "Перейти в другую зону?"
	return "Перейти в «%s»?" % zone_display_name


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if get_resolved_level_path().is_empty():
		warnings.append("Перетащите target_level (сцену уровня) в инспектор.")
	elif not ResourceLoader.exists(get_resolved_level_path()):
		warnings.append("Сцена не найдена: %s" % get_resolved_level_path())
	if get_arrival_portal_id().is_empty():
		warnings.append("Задайте arrival_portal_id (= portal_id маркера на целевой сцене).")
	return warnings
