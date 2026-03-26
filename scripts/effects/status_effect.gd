@tool
class_name StatusEffect
extends Resource

@export var duration: float = 0.0
@export var hunger_restore_per_second: float = 0.0
@export var thirst_restore_per_second: float = 0.0
@export var health_restore_per_second: float = 0.0
@export var speed_multiplier: float = 1.0

# Для будущего расширения
@export var custom_name: String = ""
@export var custom_value: float = 0.0

func process(delta: float, stats: PlayerStats):
	if duration <= 0:
		return
	
	stats.hunger += hunger_restore_per_second * delta
	stats.thirst += thirst_restore_per_second * delta
	stats.health += health_restore_per_second * delta
	
	duration -= delta
