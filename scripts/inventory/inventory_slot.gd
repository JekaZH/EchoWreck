class_name InventorySlot
extends PanelContainer

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $Count

@onready var selection: Panel = get_node_or_null("Selection")

var inventory: Inventory
var slot_index: int = -1

# Явный доступ к глобальному менеджеру (это решает проблему с сундуком)
@onready var manager = get_node("/root/InventoryManager")

# Для выделения предмета
var is_selected: bool = false
var is_active: bool = false   # новый флаг для активного слота хотбара
var take_only: bool = false   # для выходного инвентаря станций: только забирать

# Для применения через E
var use_progress_ui: UseProgressUI = null
var is_being_used: bool = false
var use_timer: float = 0.0

var _is_hovered: bool = false
var _last_compare_ctrl: bool = false
var _last_tooltip_item_id: String = ""






func setup(inv: Inventory, idx: int):
	inventory = inv
	slot_index = idx
	inventory.changed.connect(update_display)
	update_display()

func update_display():
	var stack = inventory.get_slot(slot_index)
	if stack and stack.item:
		icon.texture = stack.item.icon
		icon.modulate = _get_item_tint(stack.item)
		count_label.text = str(stack.count) if stack.count > 1 else ""
		count_label.visible = stack.count > 1
	else:
		icon.texture = null
		icon.modulate = Color.WHITE
		count_label.text = ""
		count_label.visible = false

func _get_item_tint(item: ItemData) -> Color:
	# Subtle deterministic tint so even Common items differ.
	if not item:
		return Color.WHITE
	
	# Prefer rarity color for non-common
	if item.rarity != "Common":
		return item.get_rarity_color()
	
	var h: float = float(abs(item.id.hash()) % 360) / 360.0
	return Color.from_hsv(h, 0.22, 1.0, 1.0)


func _ready():
	# Создаём прогресс-бар один раз
	if not use_progress_ui:
		use_progress_ui = preload("res://scenes/ui/use_progress.tscn").instantiate()
		get_tree().root.call_deferred("add_child", use_progress_ui)
		use_progress_ui.hide()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _process(delta):
	# Обработка зажатия E для применения
	if is_selected and Input.is_action_pressed("interact"):
		var stack = inventory.get_slot(slot_index)
		if stack and stack.item and stack.item.is_consumable:
			if not is_being_used:
				is_being_used = true
				use_timer = 0.0
				var progress_ui = manager.get_use_progress_ui()
				if progress_ui:
					progress_ui.start_use(stack.item.display_name, stack.item.use_time)

			use_timer += delta
			
			var progress_ui = manager.get_use_progress_ui()
			if progress_ui:
				progress_ui.update_progress(use_timer)

			if use_timer >= stack.item.use_time:
				apply_item(stack)
				is_being_used = false
				use_timer = 0.0
		else:
			cancel_use()
	else:
		cancel_use()
	
	var tooltip = manager.tooltip
	if tooltip and tooltip.visible:
		var mouse := get_global_mouse_position()
		var vp := get_viewport_rect().size
		var margin := Vector2(10, 10)
		var desired := mouse + Vector2(25, 25)
		
		# Tooltip size may update after deferred _fit_background; use current rect.
		var tsize: Vector2 = tooltip.size
		if tsize.x <= 1.0 or tsize.y <= 1.0:
			tsize = tooltip.get_combined_minimum_size()
		
		# Clamp to viewport; if doesn't fit below cursor, show above.
		if desired.x + tsize.x > vp.x - margin.x:
			desired.x = vp.x - tsize.x - margin.x
		if desired.y + tsize.y > vp.y - margin.y:
			desired.y = mouse.y - tsize.y - 25
		if desired.y < margin.y:
			desired.y = margin.y
		if desired.x < margin.x:
			desired.x = margin.x
		
		tooltip.global_position = desired
	
	# Live tooltip compare (Ctrl) without re-hovering.
	if _is_hovered:
		var stack2 := inventory.get_slot(slot_index)
		if stack2 and stack2.item and manager.tooltip and manager.tooltip.visible:
			var ctrl_now: bool = Input.is_key_pressed(KEY_CTRL)
			if ctrl_now != _last_compare_ctrl or stack2.item.id != _last_tooltip_item_id:
				_refresh_tooltip()


func _gui_input(event: InputEvent) -> void:
	
	if not (event is InputEventMouseButton and event.pressed):
		return

	var current = inventory.get_slot(slot_index)
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		if not get_viewport().gui_get_hovered_control() is InventorySlot:
				manager.clear_selected_slot()
		
		if Input.is_key_pressed(KEY_SHIFT) and current:
			# ───── SHIFT + ЛКМ = ПЕРЕЛОЖИТЬ В ДРУГОЙ ИНВЕНТАРЬ ─────
			var other_inventory = null
			
			# Ищем открытый другой инвентарь
			var all_uis = get_tree().get_nodes_in_group("inventory_ui")  # добавим группу позже
			for ui in all_uis:
				if not is_instance_valid(ui):
					continue
				var maybe_inv = ui.get("inventory")
				if maybe_inv is Inventory and maybe_inv != inventory:
					other_inventory = maybe_inv
					break
			
			if other_inventory:
				# Нельзя перекладывать В выход станции (туда только складывает крафт).
				if other_inventory.inventory_type == "OUTPUT" and inventory.inventory_type != "OUTPUT":
					print("Нельзя класть предметы в выход станции")
					return
				if other_inventory.can_fit_item(current.item, current.count):
					other_inventory.add_item(current.item, current.count)
					inventory.clear_slot(slot_index)
					print("Переложено:", current.count)
				else:
					print("Нет места в другом инвентаре → ничего не делаем")
				
				return
			else:
				# ───── Сундук не открыт: если это экипировка — надеть/заменить ─────
				if current.item and current.item.is_equipment:
					var player = get_tree().get_first_node_in_group("player")
					if player and player.player_equipment:
						player.player_equipment.equip_from_inventory(inventory, slot_index)
					return
				
				# Иначе — обычный выброс
				var player = get_tree().get_first_node_in_group("player")
				if player and player.is_inside_tree():
					var angle: float = player.rotation.y
					var look_dir: Vector3 = Vector3(sin(angle), 0.0, cos(angle)).normalized()
					var spawn_pos: Vector3 = player.global_position + look_dir * 2.5 + Vector3(0.0, 0.8, 0.0)
					inventory.drop_from_slot(slot_index, current.count, spawn_pos, look_dir)
				return

		# Обычный левый клик (взять / положить)
		#if manager.held_item:
			#if current == null:
				#inventory.set_slot(slot_index, manager.held_item)
				#manager.clear_held_item()
			#elif current.can_stack_with(manager.held_item):
				#var added = current.try_add(manager.held_item.count)
				#manager.held_item.count -= added
				#if manager.held_item.count <= 0:
					#manager.clear_held_item()
				#else:
					#manager.set_held_item(manager.held_item)
			#else:
				#var temp = current
				#inventory.set_slot(slot_index, manager.held_item)
				#manager.set_held_item(temp)
			#
			#inventory.changed.emit()
		#elif current:
			#manager.set_held_item(current)
			#inventory.clear_slot(slot_index)
			#inventory.changed.emit()
		if current:
			manager.set_selected_slot(self)
			print("Выделен предмет:", current.item.display_name)
			return
		else:
			manager.clear_selected_slot()

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Правый клик (кладём 1 или разделяем) — без изменений
		if manager.held_item:
			if take_only or (inventory and inventory.inventory_type == "OUTPUT"):
				return
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

			inventory.changed.emit()

		elif current and current.count > 1:
			var split_amount = ceil(current.count / 2.0)
			var split_stack = current.split(split_amount)
			if split_stack:
				manager.set_held_item(split_stack)
				inventory.changed.emit()


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
	if take_only or (inventory and inventory.inventory_type == "OUTPUT"):
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	
	# 🔥 из экипировки
	if data.has("from") and data["from"] == "equipment":
		return true
	
	# обычный инвентарь
	if data.has("stack"):
		return true
	
	return false

func _drop_data(at_position, data):
	if take_only or (inventory and inventory.inventory_type == "OUTPUT"):
		return
	# ================== ИЗ ЭКИПИРОВКИ ==================
	if data.has("from") and data["from"] == "equipment":
		var item = data["item"]
		var slot = data["slot"]
		
		var player = get_tree().get_first_node_in_group("player")
		if not player:
			return
		
		# 🔥 СНАЧАЛА снимаем
		var old_item = player.player_equipment.unequip_slot(slot)
		
		if old_item:
			inventory.add_item(old_item, 1)
		
		inventory.changed.emit()
		return
	
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


func get_other_inventory() -> Inventory:
	var all_uis = get_tree().get_nodes_in_group("inventory_ui")
	
	for ui in all_uis:
		if not is_instance_valid(ui):
			continue
		
		var maybe_inv = ui.get("inventory")
		if not (maybe_inv is Inventory):
			continue
		
		if maybe_inv != inventory:
			return maybe_inv
	
	return null

func _on_mouse_entered():
	_is_hovered = true
	_refresh_tooltip()

func _on_mouse_exited():
	_is_hovered = false
	if manager.tooltip:
		manager.tooltip.hide_tooltip()

func _refresh_tooltip() -> void:
	var stack = inventory.get_slot(slot_index)
	if not stack or not stack.item:
		if manager.tooltip:
			manager.tooltip.hide_tooltip()
		return
	
	var tooltip = manager.get_tooltip()
	if not tooltip:
		return
	
	if not tooltip.is_ready:
		await tooltip.ready
	
	var ctrl_now: bool = Input.is_key_pressed(KEY_CTRL)
	var compare_item: ItemData = null
	if ctrl_now and stack.item.is_equipment:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.player_equipment:
			compare_item = player.player_equipment.get_item_in_slot(stack.item.equipment_slot)
	
	_last_compare_ctrl = ctrl_now
	_last_tooltip_item_id = stack.item.id
	tooltip.show_tooltip(stack.item, compare_item)

func update_selection():
	if selection:
		selection.visible = is_selected
	
	# Новая рамка для активного слота
	var active_frame = get_node_or_null("ActiveFrame")
	if active_frame:
		active_frame.visible = is_active


func apply_item(stack: ItemStack):
	if not stack or not stack.item or not stack.item.is_consumable:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Ошибка: Player не найден")
		return
	
	var stats_comp = player.get_node_or_null("PlayerStatsComponent")
	if not stats_comp or not stats_comp.stats:
		print("Ошибка: PlayerStatsComponent не найден")
		return
	
	stats_comp.apply_item_effects(stack.item)
	
	# Убираем 1 предмет из стака
	if stack.count > 1:
		stack.count -= 1
	else:
		inventory.clear_slot(slot_index)

	inventory.changed.emit()
	print("Применён предмет:", stack.item.display_name)
	
	cancel_use()
	


func cancel_use():
	if is_being_used:
		is_being_used = false
		use_timer = 0.0
		var progress_ui = manager.get_use_progress_ui()
		if progress_ui:
			progress_ui.cancel()
