@tool
class_name ItemData
extends Resource

# ==================== ОСНОВНАЯ ИНФОРМАЦИЯ ====================
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99

# ==================== ДРОП НА ЗЕМЛЮ ====================
@export var mesh_on_ground: PackedScene
@export var pickup_sound: AudioStream

# ==================== КАТЕГОРИЯ И ЛУТ ====================
@export_enum("Material", "Tool", "Weapon", "Food", "Consumable", "Armor", "Misc") var category: String = "Material"
@export var loot_chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 3

# ==================== РЕДКОСТЬ ====================
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"

# ==================== ЭКИПИРОВКА В РУКУ ====================
@export_group("Экипировка в руку")
@export var is_equippable: bool = false
@export var equipped_scene: PackedScene
@export var hand_offset: Vector3 = Vector3(0, 0, 0)
@export var hand_rotation: Vector3 = Vector3(0, 0, 0)

# ==================== ИНСТРУМЕНТ ====================
@export_group("Инструмент")
@export var tool_type: String = ""              # "pickaxe", "axe", "shovel"
@export var tool_tier: int = 0                  # 0=дерево, 1=камень, 2=железо...
@export var tool_efficiency: float = 1.0        # скорость добычи
@export var tool_durability: int = 0
## Списание за один удар (добыча / атака). 0 = не изнашивается.
@export_range(0, 20, 1) var durability_loss_per_use: int = 1
@export var block_damage: float = 1.0           # урон по блокам (камни, деревья и т.д.)
@export var tool_harvest_type: String = ""      # "stone", "tree"

# ==================== ОРУЖИЕ ====================
@export_group("Оружие")
@export var is_weapon: bool = false
@export var entity_damage: float = 0.0          # урон по существам
@export var attack_speed: float = 1.0
@export var weapon_type: String = ""            # "melee", "ranged"
## Дуга удара мечом (только SWORD_ATTACK). Топор/кирка — луч InteractRay.
@export var melee_arc_reach: float = 2.0
@export var melee_arc_radius: float = 1.15
@export var melee_arc_angle_deg: float = 110.0
@export var melee_arc_height: float = 1.0
@export_range(3, 15, 1) var melee_arc_hit_samples: int = 7
## Доля reach: где по дуге ищутся цели (0.55 ≈ середина дуги).
@export_range(0.15, 1.0, 0.01) var melee_arc_hit_center_ratio: float = 0.55

@export_subgroup("Визуал удара (шейдер)")
## Пусто — `resources/combat/default_melee_slash_vfx.tres`.
@export var slash_vfx: MeleeSlashVfxSettings

enum PrimaryActionAnim { NONE, HARVEST_CHOP, SWORD_ATTACK, MAGIC_CAST }

enum MagicSphereType { NONE, FIRE, ICE, LIGHTNING }

## Какая анимация проигрывается по ЛКМ (удар / рубка). NONE — вывести из tool_type / is_weapon.
@export var primary_action_animation: PrimaryActionAnim = PrimaryActionAnim.NONE
## Множитель скорости клипа (< 1 — медленнее, удар ощутимее).
@export_range(0.2, 2.0, 0.05) var action_anim_speed_scale: float = 1.0
## Доля длительности клипа, на которой наносится урон / добыча (0.4 ≈ середина замаха).
@export_range(0.0, 1.0, 0.01) var action_hit_time_ratio: float = 0.42

# ==================== МАГИЧЕСКИЕ СФЕРЫ ====================
@export_group("Магия (сфера)")
@export var magic_sphere_type: MagicSphereType = MagicSphereType.NONE
## Пресет снаряда: урон, VFX, SINGLE_TARGET / AREA. Пусто — по magic_sphere_type (огонь → fireball).
@export var magic_projectile: MagicProjectileSettings
## Не показывать модель в руке; удар ЛКМ выпускает снаряд.
@export var magic_hide_hand_model: bool = true
## Множитель скорости анимаций каста (Enter / Shoot / Exit).
@export_range(0.5, 3.5, 0.05) var spell_cast_speed_scale: float = 1.35

# ==================== CONSUMABLE ====================
@export_group("Consumable")
@export var is_consumable: bool = false
@export var use_time: float = 1.5


# ==================== ЗВУКИ ====================
@export_group("Звуки")
## Удар инструментом по добыче (кирка по камню, топор по дереву). Пусто — без звука.
@export var tool_hit_sound: AudioStream
@export_range(-40.0, 10.0, 0.5) var tool_hit_volume_db: float = 0.0
## Удар оружием ближнего боя (меч) на кадре попадания. Пусто — без звука.
@export var weapon_hit_sound: AudioStream
@export_range(-40.0, 10.0, 0.5) var weapon_hit_volume_db: float = 0.0

# ==================== ТОПЛИВО ====================
@export_group("Топливо")
@export_range(0.0, 3600.0, 0.1) var burn_seconds: float = 0.0


# ==================== ЭКИПИРОВКА (броня, ремень и т.д.) ====================
@export_group("Экипировка (броня, одежда)")
@export var is_equipment: bool = false
@export_enum("Head", "Chest", "Legs", "Feet", "Hands", "Belt", "Ring", "Amulet") var equipment_slot: String = "Chest"

@export var armor_value: float = 0.0
@export var weight_reduction: float = 0.0
@export var equipped_model: PackedScene

# Бонусы к статам
@export var stat_additives: Dictionary = {}      # плоские добавления
@export var stat_multipliers: Dictionary = {}    # множители

# Сеты (база на будущее)
@export var set_name: String = ""                        # "Iron Set", "Explorer Set"
@export var set_bonus_threshold: int = 0                 # сколько предметов нужно для бонуса
@export var set_bonus_additives: Dictionary = {}
@export var set_bonus_multipliers: Dictionary = {}
@export var set_bonus_description: String = ""


# ==================== ЭФФЕКТЫ ====================
@export var effects: Array[ItemEffect] = []

# ==================== ОБЩИЕ ====================
@export var weight: float = 1.0
@export var custom_properties: Dictionary = {}

func resolve_primary_action_animation() -> PrimaryActionAnim:
	if primary_action_animation != PrimaryActionAnim.NONE:
		return primary_action_animation
	if magic_sphere_type != MagicSphereType.NONE:
		return PrimaryActionAnim.MAGIC_CAST
	if is_weapon and (weapon_type == "melee" or tool_type == "sword"):
		return PrimaryActionAnim.SWORD_ATTACK
	if tool_type == "axe" or tool_type == "pickaxe":
		return PrimaryActionAnim.HARVEST_CHOP
	return PrimaryActionAnim.NONE


func get_action_animation_name() -> String:
	match resolve_primary_action_animation():
		PrimaryActionAnim.HARVEST_CHOP:
			return "TreeChopping"
		PrimaryActionAnim.SWORD_ATTACK:
			return "Sword_Attack"
		_:
			return ""


func can_primary_action() -> bool:
	return not get_action_animation_name().is_empty()


func uses_melee_arc_hit() -> bool:
	return resolve_primary_action_animation() == PrimaryActionAnim.SWORD_ATTACK


func is_magic_sphere() -> bool:
	return magic_sphere_type != MagicSphereType.NONE


func get_magic_projectile_settings() -> MagicProjectileSettings:
	if magic_projectile != null:
		return magic_projectile
	match magic_sphere_type:
		MagicSphereType.FIRE:
			return MagicProjectileSettings.get_default_fire()
		MagicSphereType.ICE:
			return MagicProjectileSettings.get_default_ice()
		_:
			return MagicProjectileSettings.get_default_fire()


## Урон магического выстрела: из предмета (тултип), иначе — fallback из пресета снаряда.
func get_magic_hit_damage() -> float:
	if entity_damage > 0.0:
		return entity_damage
	return get_magic_projectile_settings().damage


func get_slash_vfx() -> MeleeSlashVfxSettings:
	if slash_vfx != null:
		return slash_vfx
	return MeleeSlashVfxSettings.get_default()


func uses_durability() -> bool:
	return tool_durability > 0


## Минимальный интервал между ударами (сек): `base_period / attack_speed`.
func get_attack_cooldown_sec(base_period: float = 1.0) -> float:
	return base_period / maxf(attack_speed, 0.25)


# Вспомогательная функция
func get_rarity_color() -> Color:
	match rarity:
		"Common":     return Color.WHITE
		"Uncommon":   return Color.LIGHT_GREEN
		"Rare":       return Color.DODGER_BLUE
		"Epic":       return Color.VIOLET
		"Legendary":  return Color.GOLD
		_:            return Color.WHITE
