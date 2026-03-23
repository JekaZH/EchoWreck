# item_data.gd
@tool
class_name ItemData
extends Resource

@export var id: String = ""                     # уникальный id ("wood_log", "iron_ore")
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
@export var width: int = 1
@export var height: int = 1
@export var shape: Array[Vector2i] = []        # относительные координаты, если не прямоугольник
												# пример L-форма: [Vector2i(0,0), Vector2i(0,1), Vector2i(1,0)]

@export var mesh_on_ground: PackedScene        # 3D модель на земле (если нужно)
@export var pickup_sound: AudioStream
@export var category: String = "material"      # material, tool, food, weapon и т.д.

@export var loot_chance: float = 1.0           # шанс выпадения из loot table
@export var min_count: int = 1
@export var max_count: int = 3
