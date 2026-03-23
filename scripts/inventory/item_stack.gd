@tool
class_name ItemStack
extends Resource

@export var item: ItemData
@export var count: int = 1

func _init(p_item: ItemData = null, p_count: int = 1):
	item = p_item
	count = clamp(p_count, 0, p_item.max_stack if p_item else 999)

func can_stack_with(other: ItemStack) -> bool:
	if not item or not other or not other.item:
		return false
	return item.id == other.item.id and item.max_stack > count

func try_add(amount: int) -> int:
	var space = (item.max_stack if item else 999) - count
	var added = min(amount, space)
	count += added
	return added

func split(amount: int) -> ItemStack:
	if amount <= 0 or amount >= count:
		return null
	var new_stack = ItemStack.new(item, amount)
	count -= amount
	return new_stack
