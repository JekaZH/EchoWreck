@tool
class_name PlayerStats
extends Resource

# Базовые статы
@export var max_health: float = 100.0
@export var health: float = 100.0

@export var max_hunger: float = 100.0
@export var hunger: float = 100.0

@export var max_thirst: float = 100.0
@export var thirst: float = 100.0

@export var max_energy: float = 100.0
@export var energy: float = 100.0

# Для будущего (легко добавлять)
@export var custom_stats: Dictionary = {}
