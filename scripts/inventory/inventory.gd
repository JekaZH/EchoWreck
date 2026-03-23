class_name Inventory
extends Node

signal changed()
signal item_dropped(stack: ItemStack, total_drop: int, spawn_pos: Vector3, look_dir: Vector3)

@export var slots_count: int = 24
@export_enum("PLAYER", "CHEST", "LOOT") var inventory_type: String = "PLAYER"

var slots: Array[ItemStack] = []   # null = пустой слот

func _ready() -> void:
	slots.resize(slots_count)
	slots.fill(null)

func add_item(new_item: ItemData, amount: int = 1) -> bool:
	if not new_item or amount <= 0:
		return false
	
	var remaining = amount
	
	# Сначала пытаемся сложить в существующие стеки
	for stack in slots:
		if stack and stack.can_stack_with(ItemStack.new(new_item)):
			var added = stack.try_add(remaining)
			remaining -= added
			if remaining <= 0:
				changed.emit()
				return true
	
	# Затем создаём новые слоты
	while remaining > 0 and slots.has(null):
		var stack_size = min(remaining, new_item.max_stack)
		var new_stack = ItemStack.new(new_item, stack_size)
		for i in slots_count:
			if slots[i] == null:
				slots[i] = new_stack
				break
		remaining -= stack_size
	
	changed.emit()
	return remaining <= 0

func get_slot(index: int) -> ItemStack:
	if index < 0 or index >= slots_count:
		return null
	return slots[index]

func set_slot(index: int, stack: ItemStack) -> void:
	if index < 0 or index >= slots_count:
		return
	slots[index] = stack
	changed.emit()

func clear_slot(index: int) -> void:
	if index < 0 or index >= slots_count:
		return
	slots[index] = null
	changed.emit()

# Для drop на землю (игрок может выбросить)
func drop_from_slot(index: int, amount: int = -1, spawn_pos: Vector3 = Vector3.ZERO, look_dir: Vector3 = Vector3.ZERO) -> void:
	var stack = get_slot(index)
	if not stack:
		return
	
	var total_drop = amount if amount > 0 else stack.count
	if total_drop > stack.count:
		total_drop = stack.count
	
	stack.count -= total_drop
	if stack.count <= 0:
		clear_slot(index)
	
	item_dropped.emit(stack, total_drop, spawn_pos, look_dir)
	changed.emit()
