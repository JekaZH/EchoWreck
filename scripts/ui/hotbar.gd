class_name Hotbar
extends Control

@export var slot_count: int = 5

var hotbar_inventory: Inventory = null
var player: Player = null
var active_slot_index: int = -1

var inventory: Inventory
@export var slot_scene: PackedScene = preload("res://scenes/inventory/inventory_slot.tscn")
@onready var background: Control = $Background
@onready var slots_container: HBoxContainer = $Background/Margin/SlotsContainer


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
	
	inventory = hotbar_inv
	refresh_slots()
	

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

	for i in slots_container.get_child_count():
		var slot = slots_container.get_child(i) as InventorySlot
		if slot:
			slot.is_active = (i == index)
			
			# Устанавливаем is_selected ТОЛЬКО если предмет consumable
			var stack = hotbar_inventory.get_slot(i)
			slot.is_selected = (i == index) and (stack and stack.item and stack.item.is_consumable)
			
			slot.update_selection()
	
	player.update_equipped_tool_from_hotbar()


func refresh_slots():
	for child in slots_container.get_children():
		child.queue_free()
	
	for i in inventory.slots_count:
		var scene := slot_scene
		if scene == null:
			scene = preload("res://scenes/inventory/inventory_slot.tscn")
		var slot = scene.instantiate()
		slots_container.add_child(slot)
		slot.setup(inventory, i)
	
	print("REFRESH HOTBAR UI")
	
	call_deferred("_fit_background")

func _fit_background() -> void:
	if not is_instance_valid(background) or not is_instance_valid(slots_container):
		return
	await get_tree().process_frame
	var size := background.get_combined_minimum_size()
	background.offset_left = 0
	background.offset_top = 0
	background.offset_right = size.x
	background.offset_bottom = size.y
	
