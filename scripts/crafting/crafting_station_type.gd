@tool
class_name CraftingStationType
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D

@export_group("Capabilities")
@export var supports_fuel: bool = false
@export var supports_queue: bool = false
@export var supports_parallel_crafts: bool = false
@export var max_parallel_crafts: int = 1

@export_group("Fuel")
@export var fuel_entries: Array[CraftFuelEntry] = []

func get_label() -> String:
	if display_name != "":
		return display_name
	if id != &"":
		return String(id)
	return "Crafting Station"
