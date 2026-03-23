# harvestable.gd
class_name Harvestable
extends Node

@onready var outline_mesh: MeshInstance3D = $"../OutlineMesh"

@export var loot_table: LootTable
@export var required_tool_type: String = ""     # "axe", "pickaxe" или пусто
@export var health: int = 3
@export var harvest_time: float = 1.5

signal harvested(drops: Array[Dictionary])      # [{item: ItemData, count: int}]

func try_harvest(player) -> bool:
	print("Вызван try_harvest на ", name, " | health до: ", health)
	
	health -= 1
	
	if health <= 0:
		var drops = generate_drops()
		harvested.emit(drops)
		print("Объект уничтожен, лут: ", drops)
		
		# Находим root инстанса дерева (самый надёжный способ)
		var tree_root = self
		while tree_root.get_owner() != null:
			tree_root = tree_root.get_owner()
		
		# Дополнительная проверка: если поднялись слишком высоко — берём родителя StaticBody3D
		if tree_root == get_tree().root or tree_root == get_tree().current_scene:
			tree_root = get_parent()  # берём родителя StaticBody3D (это TreeX)
		
		if tree_root and tree_root != self:
			print("Удаляю root дерева: ", tree_root.name, " | путь: ", tree_root.get_path())
			tree_root.queue_free()
		else:
			print("Не нашёл root — удаляю ближайшего родителя")
			get_parent().queue_free()  # fallback — удаляем StaticBody3D
		
		return true
	
	print("health после: ", health)
	return false

func generate_drops() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for entry in loot_table.entries:
		if randf() < entry.chance:
			var count = randi_range(entry.min_count, entry.max_count)
			if count > 0:
				# Запоминаем позицию ДО удаления
				var center_pos = get_parent().global_position
				
				for i in range(count):
					# Разносим каждый предмет отдельно
					var offset = Vector3(
						randf_range(-1.5, 1.5),
						1.0,  # чуть выше земли
						randf_range(-1.5, 1.5)
					)
					
					var spawn_pos = center_pos + offset
					
					# Спавним отдельный DroppedItem
					call_deferred("_spawn_dropped_item", entry.item, 1, spawn_pos)
					
					# Добавляем в результат для лога/инвентаря (если нужно)
					result.append({"item": entry.item, "count": 1})
	
	print("Сгенерировано лута: ", result)
	return result

func set_highlight(enabled: bool) -> void:
	if outline_mesh:
		outline_mesh.visible = enabled


func _on_highlight_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		set_highlight(true)


func _on_highlight_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		set_highlight(false)


# Вспомогательная функция — находит позицию без наложения
func _find_free_position(center: Vector3, max_radius: float, min_distance: float) -> Vector3:
	var attempts = 0
	var max_attempts = 10
	
	while attempts < max_attempts:
		attempts += 1
		
		var angle = randf() * PI * 2
		var distance = randf_range(0.5, max_radius)  # не ближе 0.5 м к центру
		var offset = Vector3(cos(angle) * distance, 1.0, sin(angle) * distance)
		
		var candidate = center + offset
		
		# Проверяем расстояние до уже существующих предметов
		var too_close = false
		for item in get_tree().get_nodes_in_group("dropped_items"):
			if candidate.distance_to(item.global_position) < min_distance:
				too_close = true
				break
		
		if not too_close:
			return candidate
	
	# Если не нашли — возвращаем случайную точку
	var fallback_angle = randf() * PI * 2
	var fallback_dist = randf_range(0.5, max_radius)
	return center + Vector3(cos(fallback_angle) * fallback_dist, 1.0, sin(fallback_angle) * fallback_dist)

# Вспомогательная функция (добавь в конец harvestable.gd)
func _spawn_dropped_item(item: ItemData, count: int, spawn_pos: Vector3) -> void:
	var dropped_scene = preload("res://scenes/world_objects/dropped_item/dropped_item.tscn")
	var dropped = dropped_scene.instantiate() as DroppedItem
	dropped.item_data = item
	dropped.count = count  # всегда 1
	
	get_tree().current_scene.add_child(dropped)
	dropped.global_position = spawn_pos
	
	dropped.add_to_group("dropped_items")  # для проверки расстояния
	
	print("Спавн отдельного предмета: ", item.display_name, " в позиции: ", spawn_pos)


func _on_harvested(drops: Array[Dictionary]) -> void:
	print("Дерево срублено! Выпало предметов на землю: ", drops.size())
	# НИЧЕГО не добавляем в инвентарь здесь!
	# Предметы уже выпали на землю через harvestable/tree_basic
	# Добавление будет ТОЛЬКО при нажатии E (в DroppedItem.pickup())
