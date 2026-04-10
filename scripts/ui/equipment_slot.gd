class_name EquipmentSlot
extends PanelContainer

@onready var icon: TextureRect = null
@onready var placeholder: TextureRect = null
@onready var slot_label: Label = null

@export var slot_type: String = "Belt"

var player_equipment: PlayerEquipment = null
@onready var manager = get_node("/root/InventoryManager")

func _ready():
# 🔥 ищем иконку ПРАВИЛЬНО
	icon = find_child("Icon", true, false)
	placeholder = find_child("Placeholder", true, false)
	slot_label = find_child("SlotLabel", true, false)
	
	if not icon:
		push_error("❌ EquipmentSlot: Icon не найден")
	
	if slot_label:
		slot_label.text = _slot_display_name(slot_type)
	
	if placeholder:
		placeholder.texture = _slot_placeholder_texture(slot_type)
	
	# 🔥 ВАЖНО: если equipment уже есть — обновляем
	if player_equipment:
		update_display()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not Input.is_key_pressed(KEY_SHIFT):
		return
	if not player_equipment:
		return
	
	var item := player_equipment.get_item_in_slot(slot_type)
	if not item:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Unequip and return to player inventory if possible, otherwise drop.
	var old_item: ItemData = player_equipment.unequip_slot(slot_type)
	if not old_item:
		return
	
	var inv: Inventory = player.get_node_or_null("Inventory")
	if inv and inv.can_fit_item(old_item, 1):
		inv.add_item(old_item, 1)
	else:
		var angle: float = player.rotation.y
		var look_dir: Vector3 = Vector3(sin(angle), 0.0, cos(angle)).normalized()
		var spawn_pos: Vector3 = player.global_position + look_dir * 2.5 + Vector3(0.0, 0.8, 0.0)
		if player.has_method("_on_item_dropped"):
			player._on_item_dropped(ItemStack.new(old_item, 1), 1, spawn_pos, look_dir)
	
	update_display()

func setup(equipment: PlayerEquipment):
	player_equipment = equipment
	
	# 🔥 ПОДПИСКА (ключевой момент)
	if not player_equipment.equipment_changed.is_connected(_on_equipment_changed):
		player_equipment.equipment_changed.connect(_on_equipment_changed)
	
	update_display()

func update_display():
	if not player_equipment:
		return
	
	var item = player_equipment.get_item_in_slot(slot_type)
	if icon:
		icon.texture = item.icon if item else null
	else:
		print("ОШИБКА: Icon нода не найдена в EquipmentSlot")
	
	if placeholder:
		placeholder.visible = (item == null)

# ====================== DRAG ИЗ ЭКИПИРОВКИ ======================
func _get_drag_data(_at_position):
	var item = player_equipment.get_item_in_slot(slot_type)
	if not item:
		return null
	
	var preview = TextureRect.new()
	preview.texture = item.icon
	preview.custom_minimum_size = Vector2(64, 64)
	set_drag_preview(preview)
	
	return {"item": item, "from": "equipment", "slot": slot_type}

# ====================== DROP ИЗ ИНВЕНТАРЯ ======================
func _can_drop_data(_at_position, data):
	if not data is Dictionary or not data.has("stack"):
		return false
	var stack = data["stack"] as ItemStack
	if not stack or not stack.item:
		return false
	return stack.item.is_equipment and stack.item.equipment_slot == slot_type

func _drop_data(_at_position, data):
	var stack = data["stack"] as ItemStack
	if not stack or not stack.item or not stack.item.is_equipment:
		return
	
	if stack.item.equipment_slot != slot_type:
		return
	
	# Centralized equip logic handles swapping + return/drop of previous item.
	if data.has("from_inventory") and data.has("from_index"):
		var from_inv = data["from_inventory"] as Inventory
		var from_idx = data["from_index"] as int
		if from_inv:
			player_equipment.equip_from_inventory(from_inv, from_idx)
	else:
		player_equipment.equip_item(stack.item)
	update_display()
	print("✅ Перенесён в слот ", slot_type, ": ", stack.item.display_name)

func _on_equipment_changed(slot, item):
	if slot == slot_type:
		update_display()

func _on_mouse_entered():
	if not manager:
		return
	if not player_equipment:
		return
	
	var item := player_equipment.get_item_in_slot(slot_type)
	if item:
		var tooltip = manager.get_tooltip()
		if not tooltip.is_ready:
			await tooltip.ready
		tooltip.show_tooltip(item)

func _on_mouse_exited():
	if manager and manager.tooltip:
		manager.tooltip.hide_tooltip()

func _slot_display_name(t: String) -> String:
	match t:
		"Head": return "Голова"
		"Chest": return "Тело"
		"Legs": return "Ноги"
		"Feet": return "Ступни"
		"Hands": return "Руки"
		"Belt": return "Пояс"
		"Ring": return "Кольцо"
		"Amulet": return "Амулет"
		_: return t

func _slot_placeholder_texture(t: String) -> Texture2D:
	# Icons from assets/icons/stylized_item/Armor (subtle background)
	match t:
		"Head":
			return preload("res://assets/icons/stylized_item/Armor/SODA_Icon_Armor_SteelHelmet.png")
		"Chest":
			return preload("res://assets/icons/stylized_item/Armor/SODA_Icon_Armor_LeatherVest.png")
		"Legs":
			# No dedicated pants icon in this pack; using tunic as generic bodywear.
			return preload("res://assets/icons/stylized_item/Armor/SODA_Icon_Clothing_RedTunic.png")
		"Feet":
			return preload("res://assets/icons/stylized_item/Armor/SODA_Icon_Armor_LeatherBoots.png")
		"Hands":
			return preload("res://assets/icons/stylized_item/Armor/SODA_Icon_Armor_SteelGauntlet.png")
		"Belt":
			return preload("res://assets/icons/stylized_item/Armor/SODA_Icon_Armor_LeatherBelt.png")
		"Ring":
			# No ring icon in Armor pack; using shield as a placeholder for now.
			return preload("res://assets/icons/stylized_item/Armor/SODA_Icon_Armor_WoodenShield.png")
		"Amulet":
			# No amulet icon in Armor pack; scarf reads well as accessory.
			return preload("res://assets/icons/stylized_item/Armor/SODA_Icon_Clothing_Scarf.png")
		_:
			return null
