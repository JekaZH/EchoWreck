@tool
class_name ItemEffect
extends Resource

@export_enum("Instant", "OverTime") var effect_type: String = "Instant"

# Мгновенные эффекты
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0
@export var health_restore: float = 0.0

# Эффекты со временем (бафы / дебафы)
@export var duration: float = 0.0          # 0 = мгновенный
@export var speed_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var hunger_decrease_multiplier: float = 1.0   # например 0.5 = голод уменьшается в 2 раза медленнее

# Для будущего (можно расширять)
@export var custom_effect_name: String = ""
@export var custom_value: float = 0.0
