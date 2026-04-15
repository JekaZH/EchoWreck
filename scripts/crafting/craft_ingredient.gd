@tool
class_name CraftIngredient
extends Resource

@export var item: ItemData
@export_range(1, 9999, 1) var amount: int = 1

func is_valid() -> bool:
	return item != null and amount > 0
