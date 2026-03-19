# player_conditions.gd
class_name PlayerConditions
extends Resource

@export var is_moving: bool = false
@export var is_running: bool = false
@export var is_idle: bool = true
# потом легко добавим: is_crouching, is_swimming и т.д.
