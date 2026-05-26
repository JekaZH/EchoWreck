extends Node3D
## Выравнивает объекты по terrain после его готовности (ручная или сохранённая).

@export var terrain_path: NodePath = ^"WorldTerrain"
@export var snap_terrain_details: bool = true
@export var snap_static_props: bool = true
@export var snap_ground_items: bool = false
@export var snap_chest: bool = true
@export var props_clearance_m: float = 0.02
@export var station_clearance_m: float = 0.04


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run_setup")


func _run_setup() -> void:
	await TerrainHeightQuery.when_terrain_ready(self)
	if snap_terrain_details:
		await _wait_for_terrain_details_visuals()
		await _snap_children_bottom(^"TerrainDetails", props_clearance_m)
	if snap_static_props:
		await _snap_children_bottom(^"StaticProps", station_clearance_m)
	if snap_ground_items:
		await _snap_ground_items()
	if snap_chest:
		var chest := get_node_or_null("Chest") as Node3D
		if chest:
			await TerrainHeightQuery.snap_node_bottom_to_ground_async(chest, props_clearance_m)


func _wait_for_terrain_details_visuals() -> void:
	var root := get_node_or_null(^"TerrainDetails")
	if root == null:
		return
	var props: Array[HarvestablePropRoot] = []
	for child in root.get_children():
		if child is HarvestablePropRoot:
			props.append(child as HarvestablePropRoot)
	if props.is_empty():
		return
	var deadline_ms := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline_ms:
		var ready := true
		for prop in props:
			if not prop.has_runtime_visual():
				ready = false
				break
		if ready:
			break
		await get_tree().process_frame
	await get_tree().process_frame


func _snap_children_bottom(path: NodePath, clearance: float) -> void:
	var root := get_node_or_null(path) as Node3D
	if root == null:
		return
	for child in root.get_children():
		if child is Node3D:
			await TerrainHeightQuery.snap_node_bottom_to_ground_async(child as Node3D, clearance)
		for grand in child.get_children():
			if grand is Node3D:
				await TerrainHeightQuery.snap_node_bottom_to_ground_async(grand as Node3D, clearance)


func _snap_ground_items() -> void:
	var root := get_node_or_null("GroundItems")
	if root == null:
		return
	for child in root.get_children():
		if child is DroppedItem:
			await (child as DroppedItem).ensure_settled()
