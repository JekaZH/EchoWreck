class_name PlayerStatsComponent
extends Node

signal died

@export var stats: PlayerStats = null

var active_effects: Array[StatusEffect] = []
var _base_max: Dictionary = {}
var _death_emitted: bool = false


func _ready() -> void:
	if not stats:
		stats = PlayerStats.new()

	_base_max = {
		"max_health": stats.max_health,
		"max_hunger": stats.max_hunger,
		"max_thirst": stats.max_thirst,
		"max_energy": stats.max_energy,
	}


func _process(delta: float) -> void:
	stats.hunger = max(0.0, stats.hunger - 0.08 * delta)
	stats.thirst = max(0.0, stats.thirst - 0.12 * delta)
	stats.energy = max(0.0, stats.energy - 0.15 * delta)

	for i in range(active_effects.size() - 1, -1, -1):
		var effect: StatusEffect = active_effects[i]
		effect.process(delta, stats)
		if effect.duration <= 0.0:
			active_effects.remove_at(i)

	if stats.hunger <= 5.0 or stats.thirst <= 5.0:
		stats.health = max(0.0, stats.health - 0.3 * delta)

	_clamp_current_stats()

	if stats.health <= 0.0 and not _death_emitted:
		_death_emitted = true
		died.emit()


func apply_item_effects(item: ItemData) -> void:
	if not item or item.effects.is_empty():
		return

	for effect in item.effects:
		if effect == null:
			continue
		if effect.effect_type == "Instant":
			_apply_instant_effect(effect)
		else:
			_apply_over_time_effect(effect)

	_clamp_current_stats()


func _apply_instant_effect(effect: ItemEffect) -> void:
	stats.hunger += effect.hunger_restore
	stats.thirst += effect.thirst_restore
	stats.health += effect.health_restore
	stats.energy += effect.energy_restore


func _apply_over_time_effect(effect: ItemEffect) -> void:
	if effect.duration <= 0.0:
		return
	var new_effect := StatusEffect.new()
	new_effect.duration = effect.duration
	new_effect.hunger_restore_per_second = effect.hunger_restore_per_second
	new_effect.thirst_restore_per_second = effect.thirst_restore_per_second
	new_effect.health_restore_per_second = effect.health_restore_per_second
	new_effect.energy_restore_per_second = effect.energy_restore_per_second
	new_effect.speed_multiplier = effect.speed_multiplier
	active_effects.append(new_effect)


func _clamp_current_stats() -> void:
	stats.hunger = clampf(stats.hunger, 0.0, stats.max_hunger)
	stats.thirst = clampf(stats.thirst, 0.0, stats.max_thirst)
	stats.health = clampf(stats.health, 0.0, stats.max_health)
	stats.energy = clampf(stats.energy, 0.0, stats.max_energy)


func apply_equipment_modifiers(additives: Dictionary, multipliers: Dictionary) -> void:
	stats.max_health = float(_base_max.get("max_health", stats.max_health))
	stats.max_hunger = float(_base_max.get("max_hunger", stats.max_hunger))
	stats.max_thirst = float(_base_max.get("max_thirst", stats.max_thirst))
	stats.max_energy = float(_base_max.get("max_energy", stats.max_energy))

	stats.max_health += float(additives.get("max_health", 0))
	stats.max_hunger += float(additives.get("max_hunger", 0))
	stats.max_thirst += float(additives.get("max_thirst", 0))
	stats.max_energy += float(additives.get("max_energy", 0))

	stats.custom_stats = {}
	for k in additives.keys():
		if k in ["max_health", "max_hunger", "max_thirst", "max_energy"]:
			continue
		stats.custom_stats[k] = additives[k]
	for k2 in multipliers.keys():
		stats.custom_stats[k2] = multipliers[k2]

	_clamp_current_stats()
