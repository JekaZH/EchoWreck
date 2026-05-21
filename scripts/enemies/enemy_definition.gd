class_name EnemyDefinition
extends Resource
## Данные типа врага (капсула сейчас, позже — человек / босс).

@export var id: String = "grunt"
@export var display_name: String = "Grunt"
@export var max_health: float = 36.0
@export var move_speed: float = 3.2
@export var aggro_range: float = 14.0
@export var attack_range: float = 1.65
@export var attack_damage: float = 10.0
@export var attack_windup: float = 0.35
@export var attack_cooldown: float = 1.25
@export var hit_stun_duration: float = 0.4
@export var show_debug_ranges: bool = true
@export var loot_table: LootTable
