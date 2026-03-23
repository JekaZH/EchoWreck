extends Node

var held_item: ItemStack = null

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
