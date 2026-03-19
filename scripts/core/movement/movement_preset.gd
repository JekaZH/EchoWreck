# movement_preset.gd
class_name MovementPreset
extends Resource

@export var max_speed: float = 5.0
@export var acceleration_time: float = 0.4
@export var deceleration_time: float = 0.25

@export var acceleration_curve: Curve = preload("res://resources/curves/default_acceleration.tres")
@export var deceleration_curve: Curve = preload("res://resources/curves/default_deceleration.tres")
