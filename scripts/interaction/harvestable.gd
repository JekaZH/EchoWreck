class_name Harvestable
extends Node

@onready var outline_mesh: MeshInstance3D = $"../OutlineMesh"

@export var loot_table: LootTable
@export var max_health: float = 10.0
var current_health: float = 0.0

@export var harvest_time: float = 1.5

# ─── Tier-система сбора ───
@export var required_tool_type: String = ""      # "pickaxe", "axe", "shovel"
@export var required_tier: int = 0
@export var required_harvest_type: String = ""
## Стабильный id узла добычи (уникален внутри сцены). Пусто = путь корня дерева/камня.
@export var persist_id: String = ""

signal harvested(drops: Array[Dictionary])

func _ready():
	current_health = max_health

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
	var damage = equipped_item.block_damage if equipped_item.block_damage > 0 else 1.0
	current_health -= damage

	print("Удар по блоку! Урон:", damage, " | Здоровье осталось:", current_health)

	if current_health <= 0:
		print("Блок полностью уничтожен!")
		var drops = generate_drops()
		harvested.emit(drops)
		
		# Полностью удаляем весь объект (включая mesh)
		var root = get_parent()  # StaticBody3D или корень камня
		if root and root != self:
			_register_destroyed_harvestable(root)
			root.queue_free()
		else:
			queue_free()
		return true

	return false


func generate_drops() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for entry in loot_table.entries:
		if randf() < entry.chance:
			var count = randi_range(entry.min_count, entry.max_count)
			if count > 0:
				var center_pos = get_parent().global_position
				for i in range(count):
					var offset = Vector3(
						randf_range(-1.2, 1.2),
						0.8,
						randf_range(-1.2, 1.2)
					)
					var spawn_pos = center_pos + offset
					call_deferred("_spawn_dropped_item", entry.item, 1, spawn_pos)
					result.append({"item": entry.item, "count": 1})
	return result


func _spawn_dropped_item(item: ItemData, count: int, spawn_pos: Vector3):
	var dropped_scene = preload("res://scenes/world_objects/dropped_item/dropped_item.tscn")
	var dropped = dropped_scene.instantiate() as DroppedItem
	dropped.item_data = item
	dropped.count = count
	get_tree().current_scene.add_child(dropped)
	dropped.global_position = spawn_pos
	dropped.add_to_group("dropped_items")


func set_highlight(enabled: bool) -> void:
	if outline_mesh:
		outline_mesh.visible = enabled


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
