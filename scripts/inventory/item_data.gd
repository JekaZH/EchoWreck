@tool
class_name ItemData
extends Resource

# Основная информация
@export var id: String = ""                    # уникальный id ("wood_log", "iron_ore")
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99

# Размеры для будущего grid-оккупации (пока не используем)
@export var width: int = 1
@export var height: int = 1
@export var shape: Array[Vector2i] = []

# Для дропа на землю
@export var mesh_on_ground: PackedScene
@export var pickup_sound: AudioStream

# Категория и лут
@export_enum("Material", "Tool", "Weapon", "Food", "Consumable", "Armor", "Misc") var category: String = "Material"
@export var loot_chance: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 3

# Редкость (удобный выбор в инспекторе)
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"

# ─── Для инструментов ───
@export var tool_type: String = ""              # "axe", "pickaxe", "shovel", ""
@export var tool_efficiency: float = 1.0        # множитель скорости
@export var tool_durability: int = 100

# ─── Для оружия ───
@export var is_weapon: bool = false
@export var damage: float = 0.0
@export var attack_speed: float = 1.0
@export var weapon_type: String = ""            # "melee", "ranged", "fist"

# ─── Для использования (еда, зелья, бинты и т.д.) ───
@export var is_consumable: bool = false         # ← главное поле
@export var use_time: float = 1.5               # время зарядки E в секундах

# ─── Эффекты предмета ───
@export var effects: Array[ItemEffect] = []

# Общие
@export var weight: float = 1.0

# Для будущего расширения (очень удобно)
@export var custom_properties: Dictionary = {}


# Вспомогательная функция для цвета редкости
func get_rarity_color() -> Color:
	match rarity:
		"Common":     return Color.WHITE
		"Uncommon":   return Color.LIGHT_GREEN
		"Rare":       return Color.DODGER_BLUE
		"Epic":       return Color.VIOLET
		"Legendary":  return Color.GOLD
		_:            return Color.WHITE
