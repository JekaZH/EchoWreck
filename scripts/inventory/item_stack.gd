@tool
class_name ItemStack
extends Resource

@export var item: ItemData
@export var count: int = 1
## Текущая прочность; -1 = не отслеживается.
@export var durability: int = -1


func _init(p_item: ItemData = null, p_count: int = 1) -> void:
	item = p_item
	count = clamp(p_count, 0, p_item.max_stack if p_item else 999)
	_init_durability_from_item()


func uses_durability() -> bool:
	return item != null and item.uses_durability() and durability >= 0


func _init_durability_from_item() -> void:
	if item != null and item.uses_durability():
		if durability < 0:
			durability = item.tool_durability
	else:
		durability = -1


## Списывает прочность. Возвращает true, если инструмент сломался.
func apply_wear(amount: int = 1) -> bool:
	if not uses_durability():
		return false
	var loss := maxi(amount, 1)
	durability = maxi(0, durability - loss)
	return durability <= 0


func get_durability_ratio() -> float:
	if not uses_durability():
		return 1.0
	return clampf(float(durability) / float(item.tool_durability), 0.0, 1.0)


func can_stack_with(other: ItemStack) -> bool:
	if not item or not other or not other.item:
		return false
	if item.id != other.item.id or item.max_stack <= count:
		return false
	if uses_durability() or other.uses_durability():
		return durability == other.durability
	return true


func try_add(amount: int) -> int:
	var space = (item.max_stack if item else 999) - count
	var added = min(amount, space)
	count += added
	return added


func split(amount: int) -> ItemStack:
	if amount <= 0 or amount >= count:
		return null
	var new_stack := ItemStack.new(item, amount)
	new_stack.durability = durability
	count -= amount
	return new_stack
