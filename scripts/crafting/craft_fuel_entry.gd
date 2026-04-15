@tool
class_name CraftFuelEntry
extends Resource

@export var item: ItemData
@export_range(0.1, 3600.0, 0.1) var burn_seconds: float = 10.0

func is_valid() -> bool:
	return item != null and burn_seconds > 0.0
