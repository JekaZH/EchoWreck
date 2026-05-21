@tool
class_name ItemEffect
extends Resource

@export_enum("Instant", "OverTime") var effect_type: String = "Instant"

@export_group("Мгновенно")
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0
@export var health_restore: float = 0.0
@export var energy_restore: float = 0.0

@export_group("Со временем (OverTime)")
@export var duration: float = 0.0
@export var hunger_restore_per_second: float = 0.0
@export var thirst_restore_per_second: float = 0.0
@export var health_restore_per_second: float = 0.0
@export var energy_restore_per_second: float = 0.0
@export var speed_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var hunger_decrease_multiplier: float = 1.0

@export_group("Прочее")
@export var custom_effect_name: String = ""
@export var custom_value: float = 0.0
