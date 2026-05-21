class_name EnemyBody
extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK, DEAD }

const _HEALTH_BAR_SCENE := preload("res://scenes/ui/world_health_bar.tscn")
const _DROPPED_ITEM_SCENE := preload("res://scenes/world_objects/dropped_item/dropped_item.tscn")
const _COLOR_NORMAL := Color(0.75, 0.18, 0.15, 1.0)
const _COLOR_ATTACK := Color(1.0, 0.42, 0.38, 1.0)
const _COLOR_HIT := Color(1.0, 0.55, 0.55, 1.0)

@export var definition: EnemyDefinition
## Уникальный id внутри уровня (как у Harvestable). Пусто = путь узла.
@export var persist_id: String = ""

var _health: HealthComponent
var _health_bar: Node3D
var _visual: MeshInstance3D
var _visual_material: StandardMaterial3D
var _debug_visual: EnemyDebugVisual
var _state: State = State.IDLE
var _player: Node3D
var _attack_phase_timer: float = 0.0
var _attack_cooldown_left: float = 0.0
var _attack_dealt: bool = false
var _hit_stun_left: float = 0.0


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("damageable")
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_visual = get_node_or_null("Visual") as MeshInstance3D
	_setup_visual_material()
	_debug_visual = get_node_or_null("DebugVisual") as EnemyDebugVisual
	if _debug_visual == null and (definition == null or definition.show_debug_ranges):
		_debug_visual = EnemyDebugVisual.new()
		_debug_visual.name = "DebugVisual"
		add_child(_debug_visual)
	if _debug_visual != null and definition != null:
		_debug_visual.enabled = definition.show_debug_ranges
		_debug_visual.setup_from_definition(definition)

	_health = get_node_or_null("Health") as HealthComponent
	if _health == null:
		_health = HealthComponent.new()
		_health.name = "Health"
		add_child(_health)
	if definition != null:
		_health.max_health = definition.max_health
	_health.reset_health()
	_health.died.connect(_on_died)

	call_deferred("_setup_health_bar")


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	if _hit_stun_left > 0.0:
		_hit_stun_left = maxf(_hit_stun_left - delta, 0.0)
		velocity = Vector3.ZERO
		_refresh_debug_visual()
		move_and_slide()
		return

	if _attack_cooldown_left > 0.0:
		_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		_idle()
		_refresh_debug_visual()
		move_and_slide()
		return

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > 0.05:
		look_at(global_position + to_player.normalized(), Vector3.UP)

	var aggro := definition.aggro_range if definition else 12.0
	var atk_range := definition.attack_range if definition else 1.6

	match _state:
		State.IDLE, State.CHASE:
			if dist <= atk_range and _attack_cooldown_left <= 0.0:
				_begin_attack()
			elif dist <= aggro:
				_state = State.CHASE
				_chase(to_player, dist, delta)
			else:
				_state = State.IDLE
				_idle()
		State.ATTACK:
			_process_attack(delta, dist, atk_range)

	_refresh_debug_visual()
	move_and_slide()


func _refresh_debug_visual() -> void:
	if _debug_visual == null:
		return
	var winding_up := _state == State.ATTACK and _attack_phase_timer > 0.0
	_debug_visual.refresh(_state, winding_up)


func _idle() -> void:
	velocity = Vector3.ZERO


func _chase(to_player: Vector3, dist: float, _delta: float) -> void:
	var speed := definition.move_speed if definition else 3.0
	var stop_dist := maxf((definition.attack_range if definition else 1.5) * 0.85, 0.4)
	if dist <= stop_dist:
		velocity = Vector3.ZERO
		return
	velocity = to_player.normalized() * speed


func _begin_attack() -> void:
	_state = State.ATTACK
	velocity = Vector3.ZERO
	_attack_phase_timer = definition.attack_windup if definition else 0.35
	_attack_dealt = false
	_set_visual_color(_COLOR_ATTACK)


func _cancel_attack() -> void:
	_state = State.CHASE
	_attack_phase_timer = 0.0
	_attack_dealt = true
	_set_visual_color(_COLOR_NORMAL)


func _process_attack(delta: float, dist: float, atk_range: float) -> void:
	velocity = Vector3.ZERO
	if _attack_phase_timer > 0.0:
		_attack_phase_timer = maxf(_attack_phase_timer - delta, 0.0)
		return

	if not _attack_dealt:
		_attack_dealt = true
		if dist <= atk_range * 1.15 and _player != null and _player.has_method("take_damage"):
			var dmg := definition.attack_damage if definition else 8.0
			_player.call("take_damage", dmg, self)
		_set_visual_color(_COLOR_NORMAL)

	_attack_cooldown_left = definition.attack_cooldown if definition else 1.2
	_state = State.CHASE


func take_damage(amount: float, source: Node = null) -> void:
	take_damage_info(DamageInfo.from_amount(amount, source))


func take_damage_info(info: DamageInfo) -> void:
	if _state == State.DEAD or info == null:
		return
	if _health.apply_damage(info.amount, info.source):
		_on_died()
	else:
		_flash_visual_hit()
		if _state == State.ATTACK:
			_cancel_attack()
		var stun := definition.hit_stun_duration if definition else 0.4
		_hit_stun_left = maxf(_hit_stun_left, stun)


func _on_died() -> void:
	_state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if _health_bar:
		_health_bar.queue_free()
	if _debug_visual:
		_debug_visual.queue_free()
	_register_destroyed_enemy()
	_spawn_loot()
	queue_free()


func _register_destroyed_enemy() -> void:
	var main := get_tree().current_scene
	if main == null or not main.is_ancestor_of(self):
		return
	LevelWorldCache.register_removed_enemy(
		WorldPersistKey.make(main, self, persist_id)
	)


func _spawn_loot() -> void:
	if definition == null or definition.loot_table == null:
		return
	var host := _get_drop_spawn_host()
	if host == null:
		return
	var center := global_position
	for entry in definition.loot_table.entries:
		if entry == null or entry.item == null:
			continue
		if randf() >= entry.chance:
			continue
		var drop_count := randi_range(entry.min_count, entry.max_count)
		for _i in drop_count:
			var offset := Vector3(randf_range(-0.8, 0.8), 0.35, randf_range(-0.8, 0.8))
			_spawn_dropped_item(host, entry.item, 1, center + offset)


func _get_drop_spawn_host() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("GroundItems", true, false)


func _spawn_dropped_item(host: Node, item: ItemData, count: int, spawn_pos: Vector3) -> void:
	if host == null or item == null:
		return
	var dropped := _DROPPED_ITEM_SCENE.instantiate() as DroppedItem
	if dropped == null:
		return
	dropped.item_data = item
	dropped.count = count
	host.add_child(dropped)
	dropped.global_position = spawn_pos
	dropped.add_to_group("dropped_items")


func _setup_visual_material() -> void:
	if _visual == null:
		return
	_visual_material = _visual.get_surface_override_material(0) as StandardMaterial3D
	if _visual_material == null:
		_visual_material = StandardMaterial3D.new()
		_visual_material.albedo_color = _COLOR_NORMAL
		_visual.set_surface_override_material(0, _visual_material)
	else:
		_visual_material = _visual_material.duplicate() as StandardMaterial3D
		_visual.set_surface_override_material(0, _visual_material)
	_visual_material.albedo_color = _COLOR_NORMAL


func _set_visual_color(color: Color) -> void:
	if _visual_material:
		_visual_material.albedo_color = color


func _flash_visual_hit() -> void:
	if _visual_material == null:
		return
	_set_visual_color(_COLOR_HIT)
	var tween := create_tween()
	tween.tween_property(_visual_material, "albedo_color", _COLOR_NORMAL, 0.15)


func _setup_health_bar() -> void:
	_health_bar = _HEALTH_BAR_SCENE.instantiate()
	if _health_bar == null:
		return
	add_child(_health_bar)
	_health_bar.position = Vector3(0.0, 1.15, 0.0)
	if _health_bar.has_method("bind_to"):
		_health_bar.fill_color = Color(0.82, 0.14, 0.12, 1.0)
		_health_bar.visibility_mode = HealthBarVisibilityMode.Mode.ALWAYS
		_health_bar.bind_to(_health)
		if _health_bar.has_method("_refresh_viewport_texture"):
			_health_bar.call("_refresh_viewport_texture")
