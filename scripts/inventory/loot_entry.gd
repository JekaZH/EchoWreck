# loot_entry.gd
@tool
class_name LootEntry
extends Resource

@export var item: ItemData
@export var chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 3
