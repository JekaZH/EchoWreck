@tool
class_name LevelSpawnPoint
extends Node3D

## Должен совпадать с arrival_portal_id зоны на **другом** уровне, откуда входят.
@export var portal_id: String = "default"

@export var editor_label: String = "Точка появления"
@export var spawn_offset: Vector3 = Vector3.ZERO

@export_group("Цвет в редакторе")
@export var gizmo_color: Color = Color(0.3, 0.55, 1.0, 0.65): set = _set_gizmo_color
@export var hide_gizmo_in_game: bool = true


func _set_gizmo_color(c: Color) -> void:
	gizmo_color = c
	_update_editor_visuals()


func _ready() -> void:
	add_to_group("level_spawn")
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
	for n in ["EditorDisk", "EditorArrow", "EditorLabel"]:
		var node := get_node_or_null(n) as Node3D
		if node:
			node.visible = show_mesh


func _update_editor_visuals() -> void:
	if not is_inside_tree():
		return

	for node_name in ["EditorDisk", "EditorArrow"]:
		var m := get_node_or_null(node_name) as MeshInstance3D
		if m and m.material_override is StandardMaterial3D:
			(m.material_override as StandardMaterial3D).albedo_color = gizmo_color if node_name == "EditorDisk" else gizmo_color.lightened(0.2)

	var label := get_node_or_null("EditorLabel") as Label3D
	if label:
		var title := editor_label if not editor_label.is_empty() else "СПАВН"
		label.text = "%s\nportal_id: %s" % [title, portal_id]
		label.modulate = gizmo_color.lightened(0.25)


func get_spawn_transform() -> Transform3D:
	var t: Transform3D = global_transform
	if spawn_offset != Vector3.ZERO:
		t.origin += spawn_offset
	return t


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if portal_id.strip_edges().is_empty():
		warnings.append("Задайте portal_id (латиница, без пробелов).")
	var parent := get_parent()
	if parent == null:
		return warnings
	for n in parent.get_children():
		if n == self or not (n is LevelSpawnPoint):
			continue
		if (n as LevelSpawnPoint).portal_id == portal_id:
			warnings.append("Дубликат portal_id '%s' — на уровне id должны быть разными." % portal_id)
			break
	return warnings
