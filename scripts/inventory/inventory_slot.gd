class_name InventorySlot
extends PanelContainer

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $Count

var inventory: Inventory
var slot_index: int = -1

# Явный доступ к глобальному менеджеру (это решает проблему с сундуком)
@onready var manager = get_node("/root/InventoryManager")

func setup(inv: Inventory, idx: int):
	inventory = inv
	slot_index = idx
	inventory.changed.connect(update_display)
	update_display()

func update_display():
	var stack = inventory.get_slot(slot_index)
	if stack and stack.item:
		icon.texture = stack.item.icon
		count_label.text = str(stack.count) if stack.count > 1 else ""
		count_label.visible = stack.count > 1
	else:
		icon.texture = null
		count_label.text = ""
		count_label.visible = false

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	var current = inventory.get_slot(slot_index)

	if event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_SHIFT) and current:
			# Shift + ЛКМ = выброс
			var player = get_tree().get_first_node_in_group("player")
			if player and player.is_inside_tree():
				var angle = player.rotation.y
				var look_dir = Vector3(sin(angle), 0, cos(angle)).normalized()
				var spawn_pos = player.global_position + look_dir * 2.5 + Vector3(0, 0.8, 0)
				inventory.drop_from_slot(slot_index, current.count, spawn_pos, look_dir)
			return

		if manager.held_item:
			# Кладём в этот слот
			if current == null:
				inventory.set_slot(slot_index, manager.held_item)
				manager.clear_held_item()
			elif current.can_stack_with(manager.held_item):
				var added = current.try_add(manager.held_item.count)
				manager.held_item.count -= added
				if manager.held_item.count <= 0:
					manager.clear_held_item()
				else:
					manager.set_held_item(manager.held_item)
			else:
				# Swap
				var temp = current
				inventory.set_slot(slot_index, manager.held_item)
				manager.set_held_item(temp)

			inventory.changed.emit()  # ← ОБЯЗАТЕЛЬНО после merge/swap/положения
		elif current:
			manager.set_held_item(current)
			inventory.clear_slot(slot_index)
			inventory.changed.emit()

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if manager.held_item:
			# Правый клик — кладём 1 из руки
			if current == null:
				var new_stack = ItemStack.new(manager.held_item.item, 1)
				inventory.set_slot(slot_index, new_stack)
				manager.held_item.count -= 1
			elif current.can_stack_with(manager.held_item):
				current.try_add(1)
				manager.held_item.count -= 1

			if manager.held_item.count <= 0:
				manager.clear_held_item()
			else:
				manager.set_held_item(manager.held_item)

			inventory.changed.emit()  # ← ОБЯЗАТЕЛЬНО после каждого изменения

		elif current and current.count > 1:
			# Правый клик — разделить пополам
			var split_amount = ceil(current.count / 2.0)
			var split_stack = current.split(split_amount)
			if split_stack:
				inventory.changed.emit()  # ← сразу обновляем слот после split
				manager.set_held_item(split_stack)
				


func _get_drag_data(at_position):
	var stack = inventory.get_slot(slot_index)
	if not stack:
		return null
	
	var preview = TextureRect.new()
	preview.texture = stack.item.icon
	preview.custom_minimum_size = Vector2(48, 48)
	set_drag_preview(preview)
	
	return {
		"from_inventory": inventory,
		"from_index": slot_index,
		"stack": stack
	}

func _can_drop_data(at_position, data):
	return typeof(data) == TYPE_DICTIONARY and data.has("stack")

func _drop_data(at_position, data):
	var from_inv: Inventory = data["from_inventory"]
	var from_index: int = data["from_index"]
	var dragged: ItemStack = data["stack"]

	var current = inventory.get_slot(slot_index)

	# 1. Пусто
	if current == null:
		inventory.set_slot(slot_index, dragged)
		from_inv.clear_slot(from_index)

	# 2. Merge
	elif current.can_stack_with(dragged):
		var added = current.try_add(dragged.count)
		dragged.count -= added
		
		if dragged.count <= 0:
			from_inv.clear_slot(from_index)
		else:
			from_inv.set_slot(from_index, dragged)

	# 3. Swap
	else:
		from_inv.set_slot(from_index, current)
		inventory.set_slot(slot_index, dragged)

	inventory.changed.emit()
	from_inv.changed.emit()
