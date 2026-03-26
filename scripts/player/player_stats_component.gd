class_name PlayerStatsComponent
extends Node

@export var stats: PlayerStats = null

var active_effects: Array[StatusEffect] = []

func _ready():
	if not stats:
		stats = PlayerStats.new()

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
