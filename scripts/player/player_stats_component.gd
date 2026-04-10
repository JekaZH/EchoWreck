class_name PlayerStatsComponent
extends Node

@export var stats: PlayerStats = null

var active_effects: Array[StatusEffect] = []
var _base_max: Dictionary = {}

func _ready():
	if not stats:
		stats = PlayerStats.new()
	
	_base_max = {
		"max_health": stats.max_health,
		"max_hunger": stats.max_hunger,
		"max_thirst": stats.max_thirst,
		"max_energy": stats.max_energy,
	}

func _process(delta: float):
	# Естественное уменьшение статов
	stats.hunger = max(0, stats.hunger - 0.08 * delta)
	stats.thirst = max(0, stats.thirst - 0.12 * delta)
	stats.energy = max(0, stats.energy - 0.15 * delta)

	# Применяем активные временные эффекты
	for i in range(active_effects.size() - 1, -1, -1):
		var effect = active_effects[i]
		effect.process(delta, stats)
		if effect.duration <= 0:
			active_effects.remove_at(i)

	# Урон от голода/жажды
	if stats.hunger <= 5 or stats.thirst <= 5:
		stats.health = max(0, stats.health - 0.3 * delta)

func apply_item_effects(item: ItemData):
	if not item or not item.effects:
		return

	for effect in item.effects:
		if effect.effect_type == "Instant":
			stats.hunger += effect.hunger_restore
			stats.thirst += effect.thirst_restore
			stats.health += effect.health_restore
		else:
			# Временный эффект — добавляем в активные
			var new_effect = StatusEffect.new()
			new_effect.duration = effect.duration
			new_effect.speed_multiplier = effect.speed_multiplier
			active_effects.append(new_effect)

	# Ограничиваем значения
	stats.hunger = clamp(stats.hunger, 0, stats.max_hunger)
	stats.thirst = clamp(stats.thirst, 0, stats.max_thirst)
	stats.health = clamp(stats.health, 0, stats.max_health)

func apply_equipment_modifiers(additives: Dictionary, multipliers: Dictionary) -> void:
	# Reset max stats to baseline.
	stats.max_health = float(_base_max.get("max_health", stats.max_health))
	stats.max_hunger = float(_base_max.get("max_hunger", stats.max_hunger))
	stats.max_thirst = float(_base_max.get("max_thirst", stats.max_thirst))
	stats.max_energy = float(_base_max.get("max_energy", stats.max_energy))
	
	# Apply additive modifiers (flat)
	stats.max_health += float(additives.get("max_health", 0))
	stats.max_hunger += float(additives.get("max_hunger", 0))
	stats.max_thirst += float(additives.get("max_thirst", 0))
	stats.max_energy += float(additives.get("max_energy", 0))
	
	# Store the rest in custom_stats (for UI / future combat calc)
	stats.custom_stats = {}
	for k in additives.keys():
		if k in ["max_health", "max_hunger", "max_thirst", "max_energy"]:
			continue
		stats.custom_stats[k] = additives[k]
	for k2 in multipliers.keys():
		stats.custom_stats[k2] = multipliers[k2]
	
	# Clamp current values to new maxima.
	stats.health = clamp(stats.health, 0, stats.max_health)
	stats.hunger = clamp(stats.hunger, 0, stats.max_hunger)
	stats.thirst = clamp(stats.thirst, 0, stats.max_thirst)
	stats.energy = clamp(stats.energy, 0, stats.max_energy)
