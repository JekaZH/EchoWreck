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
@export var tool_durability: int = 100
@export var block_damage: float = 1.0           # урон по блокам (камни, деревья и т.д.)
@export var tool_harvest_type: String = ""      # "stone", "tree"

# ==================== ОРУЖИЕ ====================
@export_group("Оружие")
@export var is_weapon: bool = false
@export var entity_damage: float = 0.0          # урон по существам
@export var attack_speed: float = 1.0
@export var weapon_type: String = ""            # "melee", "ranged"

# ==================== CONSUMABLE ====================
@export_group("Consumable")
@export var is_consumable: bool = false
@export var use_time: float = 1.5

# ==================== ЭФФЕКТЫ ====================
@export var effects: Array[ItemEffect] = []

# ==================== ОБЩИЕ ====================
@export var weight: float = 1.0
@export var custom_properties: Dictionary = {}

# Вспомогательная функция
func get_rarity_color() -> Color:
	match rarity:
		"Common":     return Color.WHITE
		"Uncommon":   return Color.LIGHT_GREEN
		"Rare":       return Color.DODGER_BLUE
		"Epic":       return Color.VIOLET
		"Legendary":  return Color.GOLD
		_:            return Color.WHITE
