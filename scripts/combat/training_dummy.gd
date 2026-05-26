class_name TrainingDummy
extends StaticBody3D
## Статичный манекен для проверки урона (ближний бой, магия).

const _HEALTH_BAR_SCENE := preload("res://scenes/ui/world_health_bar.tscn")
const _COLOR_NORMAL := Color(0.72, 0.68, 0.62, 1.0)
const _COLOR_HIT := Color(1.0, 0.55, 0.35, 1.0)

@export var max_health: float = 9999.0
@export var display_name: String = "Манекен"

var _health: HealthComponent
var _health_bar: Node3D
var _visual: MeshInstance3D
var _visual_material: StandardMaterial3D
var _hit_flash_left: float = 0.0


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("training_dummy")
	_visual = get_node_or_null("Visual") as MeshInstance3D
	_setup_visual_material()
	_health = get_node_or_null("Health") as HealthComponent
	if _health == null:
		_health = HealthComponent.new()
		_health.name = "Health"
		add_child(_health)
	_health.max_health = max_health
	_health.reset_health()
	_health.damaged.connect(_on_damaged)
	call_deferred("_setup_health_bar")


func _process(delta: float) -> void:
	if _hit_flash_left > 0.0:
		_hit_flash_left = maxf(_hit_flash_left - delta, 0.0)
		if _hit_flash_left <= 0.0 and _visual_material:
			_visual_material.albedo_color = _COLOR_NORMAL


func _setup_visual_material() -> void:
	if _visual == null:
		return
	_visual_material = StandardMaterial3D.new()
	_visual_material.albedo_color = _COLOR_NORMAL
	_visual_material.roughness = 0.85
	_visual.material_override = _visual_material


func _setup_health_bar() -> void:
	if _health == null:
		return
	var bar := _HEALTH_BAR_SCENE.instantiate() as WorldHealthBarDisplay
	if bar == null:
		return
	add_child(bar)
	_health_bar = bar
	bar.position = Vector3(0.0, 2.85, 0.0)
	bar.fill_color = Color(0.85, 0.35, 0.12, 1.0)
	bar.visibility_mode = HealthBarVisibilityMode.Mode.ALWAYS
	bar.bind_to(_health)
	if bar.has_method("_refresh_viewport_texture"):
		bar.call("_refresh_viewport_texture")


func take_damage(amount: float, source: Node = null) -> void:
	take_damage_info(DamageInfo.from_amount(amount, source))


func take_damage_info(info: DamageInfo) -> void:
	if info == null or _health == null:
		return
	if not _health.is_alive():
		return
	_health.apply_damage(info.amount, info.source)
	_flash_hit()


func _on_damaged(_amount: float, _source: Node) -> void:
	_flash_hit()


func _flash_hit() -> void:
	_hit_flash_left = 0.12
	if _visual_material:
		_visual_material.albedo_color = _COLOR_HIT
