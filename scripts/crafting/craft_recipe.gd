@tool
class_name CraftRecipe
extends Resource

# ==================== ОСНОВНОЕ ====================
@export_group("Core")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum(
	"Инструменты",
	"Оружие",
	"Броня и экипировка",
	"Еда и вода",
	"Расходуемые предметы",
	"Промежуточные материалы",
	"Станции и мебель",
    "Декор и полезные объекты"
) var recipe_category: String = "Промежуточные материалы"
@export_range(0, 99, 1) var recipe_tier: int = 0
@export var allow_without_station: bool = false
@export var required_station: CraftingStationType
@export_range(0.0, 3600.0, 0.1) var craft_time_seconds: float = 0.0

# ==================== ИНГРЕДИЕНТЫ / РЕЗУЛЬТАТ ====================
@export_group("Inputs/Outputs")
@export var ingredients: Array[CraftIngredient] = []
@export var result: CraftResult

# ==================== УЛУЧШЕНИЯ ====================
@export_group("Upgrades")
@export var is_upgrade: bool = false
@export var upgrade_consumes_base_item: bool = true
@export var upgrade_base_item: ItemData

# ==================== УСЛОВИЯ / ФЛАГИ ====================
@export_group("Flags")
@export var requires_fuel: bool = false
@export var requires_tool: bool = false
@export var tool_item: ItemData
@export var consumes_tool: bool = false

# Пространство под любые будущие условия
@export var special_conditions: Dictionary = {}

# ==================== ДОП. ДАННЫЕ (FX/SFX/ANIM) ====================
@export_group("Presentation")
@export var start_sound: AudioStream
@export var complete_sound: AudioStream
@export var complete_vfx: PackedScene
@export var station_animation_name: StringName = &""

func get_label() -> String:
	if display_name != "":
		return display_name
	if id != &"":
		return String(id)
	if result != null and result.item != null and result.item.display_name != "":
		return result.item.display_name
	return "Recipe"

func is_valid() -> bool:
	if result == null or not result.is_valid():
		return false
	if required_station == null and not allow_without_station:
		return false
	if ingredients.is_empty():
		return false
	for ing in ingredients:
		if ing == null or not ing.is_valid():
			return false
	if is_upgrade and upgrade_base_item == null:
		return false
	if requires_tool and tool_item == null:
		return false
	return true
