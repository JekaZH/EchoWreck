class_name Hotbar
extends Control

@export var slot_count: int = 5

@onready var slots_container: HBoxContainer = $Background/SlotsContainer

var hotbar_inventory: Inventory = null
var player: Player = null
var active_slot_index: int = -1


func _process(delta):
	if Input.is_action_just_released("interact"):
		# Сбрасываем выделение после отпускания E
		if active_slot_index >= 0:
			var active_slot = slots_container.get_child(active_slot_index) as InventorySlot
			if active_slot:
				active_slot.is_selected = false
				active_slot.update_selection()

func setup(p: Player, hotbar_inv: Inventory):
	player = p
	hotbar_inventory = hotbar_inv
	hotbar_inventory.changed.connect(_on_hotbar_changed)
	create_slots()

func create_slots():
	for child in slots_container.get_children():
		child.queue_free()
	
	for i in slot_count:
		var slot = preload("res://scenes/inventory/inventory_slot.tscn").instantiate()
		slots_container.add_child(slot)
		slot.setup(hotbar_inventory, i)

func _on_hotbar_changed():
	if active_slot_index >= 0:
		player.update_equipped_tool_from_hotbar()

func select_slot(index: int):
	if index < 0 or index >= slot_count:
		return
	
	active_slot_index = index

	# Сбрасываем все выделения
	for i in slots_container.get_child_count():
		var slot = slots_container.get_child(i) as InventorySlot
		if slot:
			slot.is_selected = false
			slot.is_active = (i == index)
			slot.update_selection()
	
	# Делаем активный слот "выделенным" для системы применения E
	var active_slot = slots_container.get_child(index) as InventorySlot
	if active_slot:
		active_slot.is_selected = true   # ← важно для зарядки E
		active_slot.update_selection()
	
	player.update_equipped_tool_from_hotbar()
