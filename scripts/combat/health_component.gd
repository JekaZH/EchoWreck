class_name HealthComponent
extends Node
## Универсальное HP для деревьев, врагов, разрушаемых объектов.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died

@export var max_health: float = 10.0
var current_health: float = 0.0


func _ready() -> void:
	reset_health()


func reset_health() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func apply_damage(amount: float, source: Node = null) -> bool:
	if current_health <= 0.0:
		return false
	var dmg := maxf(amount, 0.0)
	current_health = maxf(current_health - dmg, 0.0)
	damaged.emit(dmg, source)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()
		return true
	return false


func get_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return clampf(current_health / max_health, 0.0, 1.0)


func is_alive() -> bool:
	return current_health > 0.0
