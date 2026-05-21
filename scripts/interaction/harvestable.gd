class_name Harvestable
extends StaticBody3D

@onready var outline_mesh: MeshInstance3D = $"../OutlineMesh"

@export var loot_table: LootTable
@export var max_health: float = 10.0
@export var show_health_bar: bool = true
@export var health_bar_visibility: HealthBarVisibilityMode.Mode = HealthBarVisibilityMode.Mode.ON_DAMAGE

@export var harvest_time: float = 1.5

# ─── Tier-система сбора ───
@export var required_tool_type: String = ""      # "pickaxe", "axe", "shovel"
@export var required_tier: int = 0
@export var required_harvest_type: String = ""
## Стабильный id узла добычи (уникален внутри сцены). Пусто = путь корня дерева/камня.
@export var persist_id: String = ""

signal harvested(drops: Array[Dictionary])

const _HEALTH_BAR_SCENE := preload("res://scenes/ui/world_health_bar.tscn")
const _HealthBarDisplay := preload("res://scripts/ui/world_health_bar_display.gd")

var _health: HealthComponent
var _health_bar: Node3D


func _ready() -> void:
	_health = get_node_or_null("Health") as HealthComponent
	if _health == null:
		_health = HealthComponent.new()
		_health.name = "Health"
		add_child(_health)
	_health.max_health = max_health
	_health.reset_health()
	if show_health_bar:
		call_deferred("_setup_health_bar")

func try_harvest(player) -> bool:
	if not player or not player.has_node("ToolEquipper"):
		print("Harvestable: Player или ToolEquipper не найден")
		return false

	var tool_equipper = player.get_node("ToolEquipper")
	
	# === НОВАЯ ЛОГИКА ПОЛУЧЕНИЯ ItemData ===
	var equipped_item: ItemData = null
	
	if tool_equipper.current_tool:
		# Вариант 1: Ищем ItemData через owner или metadata (самый надёжный)
		if tool_equipper.current_tool.has_meta("item_data"):
			equipped_item = tool_equipper.current_tool.get_meta("item_data")
		
		# Вариант 2: Ищем вверх по дереву
		if not equipped_item:
			var node = tool_equipper.current_tool
			while node and not equipped_item:
				if node is ItemData:
					equipped_item = node
				node = node.get_parent()

	# Если инструмент не найден
	if not equipped_item or not equipped_item.is_equippable:
		print("Нужен правильный инструмент! (equipped_item не найден)")
		return false

	# Проверка типа инструмента
	if required_tool_type != "" and equipped_item.tool_type != required_tool_type:
		print("Нужен инструмент типа:", required_tool_type, ". У вас:", equipped_item.tool_type)
		return false

	# Проверка tier
	if equipped_item.tool_tier < required_tier:
		print("Нужен инструмент уровня", required_tier, "или выше. Текущий:", equipped_item.tool_tier)
		return false

	# === НАНОСИМ ДРОБНЫЙ УРОН ===
	var damage := equipped_item.block_damage if equipped_item.block_damage > 0 else 1.0
	var destroyed := _health.apply_damage(damage, player)

	print("Удар по блоку! Урон:", damage, " | Здоровье осталось:", _health.current_health)

	if destroyed:
		print("Блок полностью уничтожен!")
		var harvest_root := _get_harvest_root()
		var drops := generate_drops(harvest_root)
		harvested.emit(drops)
		_destroy_harvest_root(harvest_root)
		return true

	return false


func _get_harvest_root() -> Node3D:
	var parent := get_parent()
	if parent is Node3D:
		return parent as Node3D
	return self


func _destroy_harvest_root(harvest_root: Node) -> void:
	if harvest_root == null or not is_instance_valid(harvest_root):
		queue_free()
		return
	if harvest_root != self:
		_register_destroyed_harvestable(harvest_root)
		harvest_root.queue_free()
	else:
		queue_free()


func generate_drops(harvest_root: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if loot_table == null or harvest_root == null:
		return result

	var center_pos := harvest_root.global_position
	var host := _get_drop_spawn_host()

	for entry in loot_table.entries:
		if entry == null or entry.item == null:
			continue
		if randf() >= entry.chance:
			continue
		var drop_count := randi_range(entry.min_count, entry.max_count)
		for _i in drop_count:
			var offset := Vector3(
				randf_range(-1.2, 1.2),
				0.35,
				randf_range(-1.2, 1.2)
			)
			var spawn_pos := center_pos + offset
			if _spawn_dropped_item(host, entry.item, 1, spawn_pos):
				result.append({"item": entry.item, "count": 1})
	return result


func _get_drop_spawn_host() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var ground := scene.find_child("GroundItems", true, false)
	if ground != null:
		return ground
	return scene


func _spawn_dropped_item(host: Node, item: ItemData, count: int, spawn_pos: Vector3) -> bool:
	if host == null or item == null:
		return false
	var dropped_scene := preload("res://scenes/world_objects/dropped_item/dropped_item.tscn")
	var dropped := dropped_scene.instantiate() as DroppedItem
	if dropped == null:
		return false
	dropped.item_data = item
	dropped.count = count
	host.add_child(dropped)
	dropped.global_position = spawn_pos
	dropped.add_to_group("dropped_items")
	return true


func set_highlight(enabled: bool) -> void:
	if outline_mesh:
		outline_mesh.visible = enabled
	if _health_bar and _health_bar.has_method("set_highlighted"):
		_health_bar.set_highlighted(enabled)


func _setup_health_bar() -> void:
	var harvest_root := _get_harvest_root()
	if harvest_root == null:
		return
	_health_bar = _HEALTH_BAR_SCENE.instantiate()
	if _health_bar == null:
		return
	_health_bar.visibility_mode = health_bar_visibility
	harvest_root.add_child(_health_bar)
	_health_bar.position = Vector3(0.0, _HealthBarDisplay.estimate_top_offset(harvest_root), 0.0)
	if _health_bar.has_method("bind_to"):
		_health_bar.bind_to(_health)


func _register_destroyed_harvestable(root: Node) -> void:
	if root == null:
		return
	var main := get_tree().current_scene
	if main == null or not main.is_ancestor_of(root):
		return
	LevelWorldCache.register_removed_harvestable(
		WorldPersistKey.make(main, root, persist_id)
	)


func _on_highlight_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		set_highlight(true)


func _on_highlight_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		set_highlight(false)
