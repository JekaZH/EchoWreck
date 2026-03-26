extends Node

var held_item: ItemStack = null
var selected_slot: InventorySlot = null
var tooltip: ItemTooltip = null
var use_progress_ui: UseProgressUI = null

func set_held_item(stack: ItemStack):
	held_item = stack
	print("set_held_item: ", held_item.item.display_name if held_item else "null")
	if held_item:
		DragPreview.show_preview(held_item)
	else:
		DragPreview.hide_preview()

func clear_held_item():
	held_item = null
	print("clear_held_item")
	DragPreview.hide_preview()

func set_selected_slot(slot: InventorySlot):
	if selected_slot and is_instance_valid(selected_slot):
		selected_slot.is_selected = false
		selected_slot.update_selection()
	
	selected_slot = slot
	
	if selected_slot:
		selected_slot.is_selected = true
		selected_slot.update_selection()

func clear_selected_slot():
	if selected_slot and is_instance_valid(selected_slot):
		selected_slot.is_selected = false
		selected_slot.update_selection()
	
	selected_slot = null

func get_tooltip() -> ItemTooltip:
	if tooltip and is_instance_valid(tooltip):
		return tooltip
	
	tooltip = preload("res://scenes/ui/item_tooltip.tscn").instantiate()
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.ui_layer:
		player.ui_layer.call_deferred("add_child", tooltip)
	else:
		get_tree().root.call_deferred("add_child", tooltip)
	
	tooltip.hide()
	return tooltip

func get_use_progress_ui() -> UseProgressUI:
	if use_progress_ui and is_instance_valid(use_progress_ui):
		return use_progress_ui
	
	use_progress_ui = preload("res://scenes/ui/use_progress.tscn").instantiate()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.ui_layer:
		player.ui_layer.add_child(use_progress_ui)
	else:
		get_tree().root.call_deferred("add_child", use_progress_ui)
	
	use_progress_ui.hide()
	return use_progress_ui
