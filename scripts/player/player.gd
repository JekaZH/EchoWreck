class_name Player
extends CharacterBody3D

const PhysicsSettings := preload("res://scripts/player/player_physics_settings.gd")
const AudioClipSettings := preload("res://scripts/audio/audio_stream_clip_settings.gd")
const FootstepSettings := preload("res://scripts/player/player_footstep_settings.gd")

# Настройки
@export var camera: Camera3D
@export var walk_preset: MovementPreset
@export var run_preset: MovementPreset
@export var conditions: PlayerConditions
@export var run_deceleration_multiplier: float = 2.0
@export var mouse_look_speed: float = 10.0          # скорость поворота к курсору (когда НЕ бежим)
@export var interact_distance: float = 3.0
## Множитель скорости ходьбы при energy <= 0 (бег отключён).
@export_range(0.1, 1.0, 0.05) var exhausted_walk_speed_multiplier: float = 0.55
## Базовый период между ударами при attack_speed = 1 (сек). Итог: period / attack_speed предмета.
@export_range(0.25, 2.5, 0.05) var base_attack_cooldown_sec: float = 0.9
@export var dash_settings: PlayerDashSettings
@export var footstep_settings: FootstepSettings
@export var physics_settings: PhysicsSettings

@onready var anim_tree: AnimationTree = $PlayerAnimTree
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var interact_ray: RayCast3D = $InteractRay

@onready var stats_component: PlayerStatsComponent = $PlayerStatsComponent

var current_inventory_ui: Control = null
var current_crafting_ui: Control = null
var current_crafting_station: CraftingStation = null
@onready var inventory: Inventory = $Inventory
@onready var ui_layer: CanvasLayer = $UI_Layer

@onready var inventory_ui_scene: PackedScene = preload("res://scenes/inventory/universal_inventory.tscn")


@onready var hotbar_ui: Hotbar = null
@onready var hotbar_inventory: Inventory = null
var equipped_slot_index: int = -1   # текущий выбранный слот hotbar

var base_hotbar_slots: int = 5
var bonus_hotbar_slots: int = 0


@onready var tool_equipper: ToolEquipper = $ToolEquipper



@onready var player_equipment: PlayerEquipment = $PlayerEquipment
@onready var equipment_panel_scene: PackedScene = preload("res://scenes/ui/equipment_panel.tscn")
@onready var stats_summary_panel_scene: PackedScene = preload("res://scenes/ui/player_stats_summary_panel.tscn")

var current_equipment_panel = null
var current_stats_summary_panel = null

@onready var stats_ui: PlayerStatsUI = null

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu/pause_menu.tscn")
const DEATH_SCREEN_SCENE := preload("res://scenes/ui/death_screen/death_screen.tscn")
const SWORD_SLASH_VFX_SCENE := preload("res://scenes/combat/sword_slash_vfx.tscn")
const MAGIC_PROJECTILE_SCENE := preload("res://scenes/combat/magic_projectile.tscn")
var _pause_menu: PauseMenuController
var _death_screen: DeathScreenController
var _is_dead: bool = false
var _ui_layer_visible_before_screenshot: bool = true

var _nearby_interactables: Array[Node3D] = []
var _active_interactable: Node3D = null
var _interaction_prompt: InteractionPrompt = null




var nearby_dropped_items: Array[DroppedItem] = []
var direction: Vector3 = Vector3.ZERO
var last_moving: bool = false
var last_running: bool = false
var _action_animator: PlayerActionAnimator
var _movement_locked: bool = false
var _pending_pickup: bool = false
var _next_attack_allowed_msec: int = 0
var _next_dash_allowed_msec: int = 0
## Направление выстрела фиксируется в момент нажатия ЛКМ (не при повороте во время каста).
var _locked_spell_aim: Vector3 = Vector3.ZERO
var _has_locked_spell_aim: bool = false

## Минимальная дистанция до точки прицеливания на земле (м), иначе — взгляд персонажа.
const SPELL_AIM_MIN_DISTANCE_M := 0.1
const SPELL_AIM_MIN_DISTANCE_SQ := SPELL_AIM_MIN_DISTANCE_M * SPELL_AIM_MIN_DISTANCE_M
## Маркер «луч в землю не попал» (не используй как реальную позицию).
const NO_GROUND_HIT := Vector3(INF, INF, INF)

var _footstep_distance_m: float = 0.0
var _footstep_cooldown_sec: float = 0.0
var _footstep_had_move_input: bool = false
var _footstep_player: AudioStreamPlayer3D
var _action_audio: AudioStreamPlayer3D

func _ready() -> void:
	if dash_settings == null:
		dash_settings = PlayerDashSettings.get_default()
	if footstep_settings == null:
		footstep_settings = FootstepSettings.get_default()
	if physics_settings == null:
		physics_settings = PhysicsSettings.get_default()
	_configure_character_physics()
	_setup_footstep_audio()
	stats_component.stats = PlayerStats.new()  # или загружай сохранённые статы

	# До await: чтобы загрузка сейва из Main._ready не застала hotbar_inventory = null.
	hotbar_inventory = $HotbarInventory
	hotbar_inventory.slots_count = base_hotbar_slots
	hotbar_inventory.item_dropped.connect(_on_item_dropped)

	anim_tree.active = true
	_action_animator = PlayerActionAnimator.new()
	_action_animator.name = "ActionAnimator"
	add_child(_action_animator)
	_action_animator.setup(self, anim_tree, anim_player)
	_action_animator.action_hit_frame.connect(_on_action_hit_frame)
	_action_animator.action_recovery.connect(_on_action_recovery)
	_action_animator.action_finished.connect(_on_action_anim_finished)
	await get_tree().process_frame
	
	inventory.item_dropped.connect(_on_item_dropped)
	hotbar_ui = preload("res://scenes/ui/hotbar.tscn").instantiate()
	ui_layer.add_child(hotbar_ui)
	hotbar_ui.setup(self, hotbar_inventory)

	# === Player stats UI ===
	stats_ui = preload("res://scenes/ui/player_stats_ui.tscn").instantiate()
	ui_layer.add_child(stats_ui)
	stats_ui.setup(stats_component.stats)

	_interaction_prompt = preload("res://scenes/ui/interaction/interaction_prompt.tscn").instantiate()
	ui_layer.add_child(_interaction_prompt)
	_interaction_prompt.set_visible_prompt(false)

	_pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenuController
	add_child(_pause_menu)

	_death_screen = DEATH_SCREEN_SCENE.instantiate() as DeathScreenController
	add_child(_death_screen)

	if stats_component:
		stats_component.died.connect(_on_player_died)

	SaveManager.before_screenshot_capture.connect(_on_before_save_screenshot_hide_ui)
	SaveManager.after_screenshot_capture.connect(_on_after_save_screenshot_restore_ui)
	
	print("Hotbar успешно инициализирован с 5 слотами")
	
	var harvestables = get_tree().get_nodes_in_group("harvestable")
	print("Найдено harvestable: ", harvestables.size())
	for h in harvestables:
		if h.has_signal("harvested"):
			if not h.harvested.is_connected(_on_harvested):
				h.harvested.connect(_on_harvested)
				print("Подключил harvested к ", h.name)


func _on_before_save_screenshot_hide_ui() -> void:
	if ui_layer:
		_ui_layer_visible_before_screenshot = ui_layer.visible
		ui_layer.visible = false


func _on_after_save_screenshot_restore_ui() -> void:
	if ui_layer:
		ui_layer.visible = _ui_layer_visible_before_screenshot


func _on_player_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	_movement_locked = true
	if _action_animator:
		_action_animator.play_death()
	close_all_ui()
	if _pause_menu and _pause_menu.is_menu_open():
		_pause_menu.close_menu()
	if _death_screen:
		_death_screen.open_screen()


func is_dead() -> bool:
	return _is_dead


func handle_hotbar_shrink(target_slots_count: int) -> void:
	if not hotbar_inventory:
		return
	if target_slots_count >= hotbar_inventory.slots_count:
		return
	if not inventory:
		return
	
	var angle := rotation.y
	var look_dir := Vector3(sin(angle), 0, cos(angle)).normalized()
	var spawn_pos := global_position + look_dir * 2.5 + Vector3(0, 0.8, 0)
	
	for idx in range(target_slots_count, hotbar_inventory.slots_count):
		var stack := hotbar_inventory.get_slot(idx)
		if not stack or not stack.item or stack.count <= 0:
			continue
		
		var item := stack.item
		var remaining := stack.count
		
		# Try to move to main inventory first (as much as possible).
		while remaining > 0 and inventory.can_fit_item(item, 1):
			inventory.add_item(item, 1)
			remaining -= 1
		
		# Drop what's left.
		if remaining > 0:
			hotbar_inventory.drop_from_slot(idx, remaining, spawn_pos, look_dir)
		else:
			hotbar_inventory.clear_slot(idx)

func _input(event: InputEvent) -> void:
	if _is_dead:
		return

	# === ВЫБОР СЛОТОВ HOTBAR КЛАВИШАМИ 1-5 ===
	for i in 5:
		if event.is_action_pressed("hotbar_slot_" + str(i + 1)):
			if hotbar_ui:
				hotbar_ui.select_slot(i)
			print("Hotbar: выбран слот", i + 1)
			break

	if event.is_action_pressed("interact"):
		if hotbar_ui and hotbar_ui.active_slot_index >= 0:
			var active_slot = hotbar_ui.slots_container.get_child(hotbar_ui.active_slot_index) as InventorySlot
			if active_slot:
				var stack = hotbar_inventory.get_slot(hotbar_ui.active_slot_index)
				if stack and stack.item and stack.item.is_consumable:
					active_slot.is_selected = true
					active_slot.update_selection()
		
		# Если рядом нет дропа — сначала пробуем интеракцию по "активному" объекту из Area3D,
		# чтобы не было конфликтов при пересечении нескольких зон.
		if nearby_dropped_items.is_empty():
			if _active_interactable != null and is_instance_valid(_active_interactable) and _active_interactable.has_method("interact"):
				_active_interactable.interact(self)
			else:
				_try_interact_raycast()

	# ====================== ИНВЕНТАРЬ ======================
	if event.is_action_pressed("inventory"):
		var all_uis = get_tree().get_nodes_in_group("inventory_ui")
		var has_chest = false
		for ui in all_uis:
			if is_instance_valid(ui):
				var title = ui.get("title")
				if title == "Сундук":
					has_chest = true
					break

		if has_chest:
			close_all_ui()
			print("Сундук открыт — закрываем все окна")
			return

		# Обычное переключение инвентаря
		if current_inventory_ui and is_instance_valid(current_inventory_ui):
			current_inventory_ui.queue_free()
			current_inventory_ui = null
			if current_equipment_panel and is_instance_valid(current_equipment_panel):
				current_equipment_panel.queue_free()
				current_equipment_panel = null
			if current_stats_summary_panel and is_instance_valid(current_stats_summary_panel):
				current_stats_summary_panel.queue_free()
				current_stats_summary_panel = null
			print("Инвентарь закрыт")
		else:
			# Не накладываем интерфейсы друг на друга.
			close_all_ui()
			var ui = preload("res://scenes/inventory/universal_inventory.tscn").instantiate()
			ui.inventory = $Inventory
			ui.title = "Инвентарь"
			ui.columns = 6
			ui.show_close_button = true
			ui.add_to_group("inventory_ui")
			$UI_Layer.add_child(ui)
			current_inventory_ui = ui
			print("Инвентарь открыт")

			# Добавляем панель экипировки
			var eq_panel = equipment_panel_scene.instantiate()
			eq_panel.setup(player_equipment)
			eq_panel.add_to_group("inventory_ui")   # ← ВАЖНО
			$UI_Layer.add_child(eq_panel)
			current_equipment_panel = eq_panel
			
			# Позиционируем панель справа от окна инвентаря (чтобы не перекрывалась)
			if eq_panel.has_method("place_next_to"):
				eq_panel.place_next_to(ui, "RIGHT")
			
			# Отдельная панель параметров (отдельное окно, не ребёнок экипировки)
			var stats_panel = stats_summary_panel_scene.instantiate()
			stats_panel.add_to_group("inventory_ui")
			$UI_Layer.add_child(stats_panel)
			current_stats_summary_panel = stats_panel
			if stats_panel is PlayerStatsSummaryPanel:
				(stats_panel as PlayerStatsSummaryPanel).setup(player_equipment, stats_component)
				(stats_panel as PlayerStatsSummaryPanel).place_next_to(eq_panel, "RIGHT")
			
			# Принудительно обновляем все слоты экипировки
			for child in eq_panel.get_children():
				if child is EquipmentSlot:
					child.update_display()

	# ====================== КРАФТ ======================
	if event.is_action_pressed("crafting_menu"):
		# K — меню крафта (пока без фильтра по станции)
		if current_crafting_ui and is_instance_valid(current_crafting_ui):
			current_crafting_ui.queue_free()
			current_crafting_ui = null
			print("Крафт закрыт")
			return
		open_crafting_ui(null)
		print("Крафт открыт (K)")
			

	# ====================== ESC / пауза ======================
	elif event.is_action_pressed("ui_cancel") and not _is_dead:
		if _pause_menu and _pause_menu.is_menu_open():
			_pause_menu.close_menu()
			get_viewport().set_input_as_handled()
			return
		var inv_nodes := get_tree().get_nodes_in_group("inventory_ui")
		if inv_nodes.size() > 0:
			close_all_ui()
			print("Esc — все окна закрыты")
			get_viewport().set_input_as_handled()
			return
		close_all_ui()
		if _pause_menu:
			_pause_menu.open_menu()
			get_viewport().set_input_as_handled()
			print("Esc — меню паузы")

func _physics_process(delta: float) -> void:
	if camera == null:
		return
	if _is_dead:
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		return

	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var has_move_input := move_input.length() > 0.05
	var input_dir := Vector2.ZERO
	if not _movement_locked:
		input_dir = move_input
	var energy_ok := stats_component != null and stats_component.stats != null and stats_component.stats.energy > 0.0
	var is_running := Input.is_action_pressed("run") and energy_ok and not _movement_locked
	var wants_to_move := input_dir.length() > 0.05
	var walk_speed_scale := 1.0
	if not energy_ok:
		walk_speed_scale = exhausted_walk_speed_multiplier
	
	# ────────────────────────────────────────────────
	# 1. Поворот к курсору — ТОЛЬКО когда НЕ бежим
	#    (плавный lerp, чтобы при проходе через курсор был плавный разворот на 180°)
	# ────────────────────────────────────────────────
	if not is_running:
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_dir = camera.project_ray_normal(mouse_pos)
		
		var ground_point := _get_cursor_point_on_ground()
		if _cursor_hits_ground(ground_point):
			var look_at_point := ground_point
			look_at_point.y = global_position.y
			var look_dir := (look_at_point - global_position).normalized()
			look_dir.y = 0.0
			if look_dir.length_squared() >= SPELL_AIM_MIN_DISTANCE_SQ:
				var target_angle = atan2(look_dir.x, look_dir.z)
				rotation.y = lerp_angle(rotation.y, target_angle, mouse_look_speed * delta)
	
	# ────────────────────────────────────────────────
	# 2. Движение (твой оригинальный код почти без изменений)
	# ────────────────────────────────────────────────
	var cam_forward = camera.global_transform.basis.z.normalized()
	cam_forward.y = 0
	var cam_right = camera.global_transform.basis.x.normalized()
	cam_right.y = 0
	
	direction = (cam_right * input_dir.x + cam_forward * input_dir.y).normalized()
	
	var using_run_preset := is_running and wants_to_move
	var preset: MovementPreset = run_preset if using_run_preset else walk_preset
	var speed_cap: float = preset.max_speed
	if not using_run_preset:
		speed_cap *= walk_speed_scale
	var move_dir := _get_floor_aligned_move_direction(direction)
	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)

	if wants_to_move:
		var forward_dir := move_dir
		if forward_dir.length_squared() > 0.0001:
			forward_dir = forward_dir.normalized()
		else:
			forward_dir = Vector3.ZERO
		var forward_component := horizontal_vel.dot(forward_dir)
		forward_component = maxf(0.0, forward_component)
		var perp := horizontal_vel - forward_dir * forward_component
		perp = perp.move_toward(Vector3.ZERO, 60.0 * delta)
		horizontal_vel = forward_dir * forward_component + forward_dir * (speed_cap / preset.acceleration_time) * delta
		if horizontal_vel.length() > speed_cap:
			horizontal_vel = horizontal_vel.normalized() * speed_cap
		if is_running and move_dir.length_squared() > 0.01:
			var move_angle := atan2(move_dir.x, move_dir.z)
			rotation.y = lerp_angle(rotation.y, move_angle, 12.0 * delta)
	else:
		var decel := speed_cap / preset.deceleration_time
		if last_running:
			decel *= run_deceleration_multiplier
		horizontal_vel = horizontal_vel.move_toward(Vector3.ZERO, decel * delta)

	velocity.x = horizontal_vel.x
	velocity.z = horizontal_vel.z
	_apply_gravity(delta)
	
	var is_moving_now := direction.length() > 0.1 and wants_to_move
	var is_running_now := is_running and is_moving_now

	move_and_slide()
	_update_footsteps(delta, is_moving_now, is_running_now, has_move_input)
	_update_interaction_prompt()
	
	# Условия анимации
	
	last_moving = is_moving_now
	last_running = is_running_now
	
	if anim_tree and anim_tree.active:
		anim_tree.set("parameters/conditions/is_moving", is_moving_now)
		anim_tree.set("parameters/conditions/is_running", is_running_now)
		anim_tree.set("parameters/conditions/is_not_moving", not is_moving_now)
		anim_tree.set("parameters/conditions/is_not_running", not is_running_now)
		anim_tree.set("parameters/conditions/is_tree_chopping", false)
	
	if Input.is_action_just_pressed("dash") and not _is_dead:
		_try_dash()

	if Input.is_action_just_pressed("attack") and not _movement_locked and _can_attack_now():
		_try_start_attack_action()
	
	if Input.is_action_just_pressed("interact") and not _movement_locked:
		if nearby_dropped_items.size() > 0:
			_try_start_pickup_action()

	if Input.is_action_just_pressed(DroppedItemHighlight.ACTION_TOGGLE_OUTLINES):
		DroppedItemHighlight.toggle_outlines()

func _on_harvested(drops: Array[Dictionary]) -> void:
	print("Дерево срублено! Выпало предметов на землю: ", drops.size())
	# НИЧЕГО не добавляем в инвентарь здесь!
	# Предметы уже выпали на землю через harvestable/tree_basic
	# Добавление будет ТОЛЬКО при нажатии E (в DroppedItem.pickup())


func _on_item_dropped(stack: ItemStack, total_drop: int, spawn_pos: Vector3, look_dir: Vector3) -> void:
	for i in total_drop:
		var offset = Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.4), randf_range(-0.6, 0.6))
		var final_pos = spawn_pos + offset
		
		var dropped := preload("res://scenes/world_objects/dropped_item/dropped_item.tscn").instantiate() as DroppedItem
		dropped.item_data = stack.item
		dropped.count = 1
		get_tree().current_scene.add_child(dropped)
		dropped.global_position = final_pos
		dropped.call_deferred("apply_drop_impulse", look_dir)
		
		print("Выброшен 1 предмет: ", stack.item.display_name, " на ", final_pos)

func get_equipped_item_data() -> ItemData:
	if tool_equipper != null and tool_equipper.current_tool != null:
		if tool_equipper.current_tool.has_meta("item_data"):
			return tool_equipper.current_tool.get_meta("item_data") as ItemData
	return _get_active_hotbar_item_data()


func _get_active_hotbar_item_data() -> ItemData:
	if hotbar_ui == null or hotbar_inventory == null:
		return null
	if hotbar_ui.active_slot_index < 0:
		return null
	var stack := hotbar_inventory.get_slot(hotbar_ui.active_slot_index)
	if stack == null or stack.item == null:
		return null
	return stack.item


func _face_cursor_instant() -> void:
	var ground_point := _get_cursor_point_on_ground()
	if not _cursor_hits_ground(ground_point):
		return
	var look_dir := ground_point - global_position
	look_dir.y = 0.0
	if look_dir.length_squared() >= SPELL_AIM_MIN_DISTANCE_SQ:
		rotation.y = atan2(look_dir.x, look_dir.z)


func _can_attack_now() -> bool:
	return Time.get_ticks_msec() >= _next_attack_allowed_msec


func _try_start_attack_action() -> void:
	if _action_animator == null or _action_animator.is_busy():
		return
	var item := get_equipped_item_data()
	if item == null:
		return
	if item.resolve_primary_action_animation() == ItemData.PrimaryActionAnim.MAGIC_CAST:
		_try_cast_magic(item)
		return
	if not item.can_primary_action():
		return
	if not _has_equipped_tool_durability():
		return
	_face_cursor_instant()
	if _action_animator.play_item_action(item):
		_movement_locked = true
		var cd_sec := item.get_attack_cooldown_sec(base_attack_cooldown_sec)
		_next_attack_allowed_msec = Time.get_ticks_msec() + int(cd_sec * 1000.0)


func _try_start_pickup_action() -> void:
	if _action_animator == null or _action_animator.is_busy():
		return
	if nearby_dropped_items.is_empty():
		return
	_face_cursor_instant()
	if _action_animator.try_play_pickup():
		_pending_pickup = true
		_movement_locked = true


func _on_action_hit_frame() -> void:
	var item := get_equipped_item_data()
	if item != null and item.is_magic_sphere():
		_spawn_magic_projectile(item)
		_movement_locked = false
		return
	if _apply_primary_action_hit():
		_apply_equipped_tool_wear()
	_movement_locked = false


func _on_action_recovery() -> void:
	if _action_animator != null and _action_animator.is_spell_chain_active():
		return
	_movement_locked = false


func _on_action_anim_finished(kind: String) -> void:
	if kind == "spell":
		_has_locked_spell_aim = false
		_movement_locked = false
	elif kind != "death":
		_movement_locked = false
	if kind == "pickup" and _pending_pickup:
		_pending_pickup = false
		_pickup_closest_dropped_item()


func _apply_primary_action_hit() -> bool:
	var item := get_equipped_item_data()
	if item == null:
		return false
	if item.is_magic_sphere():
		return false
	if item.uses_melee_arc_hit():
		return _apply_sword_arc_hit(item)
	return _apply_tool_ray_hit(item)


func _try_cast_magic(item: ItemData) -> void:
	if item == null or not item.is_magic_sphere():
		return
	if _action_animator == null or _action_animator.is_busy():
		return
	if not _can_attack_now():
		return
	_face_cursor_instant()
	_locked_spell_aim = _get_aim_direction_from_cursor()
	_has_locked_spell_aim = true
	var cfg := item.get_magic_projectile_settings()
	_play_action_sound(cfg.cast_sound, cfg.cast_sound_volume_db)
	if not _action_animator.play_spell_cast(item):
		_has_locked_spell_aim = false
		push_warning("Player: не удалось начать анимацию заклинания")
		return
	_movement_locked = true
	var cd_sec := item.get_attack_cooldown_sec(base_attack_cooldown_sec)
	_next_attack_allowed_msec = Time.get_ticks_msec() + int(cd_sec * 1000.0)


func _spawn_magic_projectile(item: ItemData) -> void:
	if item == null or not item.is_magic_sphere():
		return
	var cfg := item.get_magic_projectile_settings()
	var aim := _locked_spell_aim if _has_locked_spell_aim else _get_aim_direction_from_cursor()
	_has_locked_spell_aim = false
	var emit_origin := _get_spell_emit_origin(cfg, aim)
	var spawn_pos := emit_origin + aim * cfg.spawn_offset_forward_m
	MagicCastVfx.play_shoot(emit_origin, aim, cfg)
	var projectile := MAGIC_PROJECTILE_SCENE.instantiate() as MagicProjectile
	if projectile == null:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(projectile)
	var damage := item.get_magic_hit_damage()
	projectile.launch(spawn_pos, aim, cfg, self, damage)
	SaveManager.mark_unsaved_changes()


func clear_locked_spell_aim() -> void:
	_has_locked_spell_aim = false


func _get_spell_emit_origin(cfg: MagicProjectileSettings, aim: Vector3) -> Vector3:
	var direction := aim if aim.length_squared() > SPELL_AIM_MIN_DISTANCE_SQ else _get_flat_forward()
	if tool_equipper != null and tool_equipper.grip_node != null and is_instance_valid(tool_equipper.grip_node):
		return tool_equipper.grip_node.global_position + direction * cfg.cast_offset_from_grip_m
	return global_position + Vector3(0.0, cfg.cast_height_above_feet_m, 0.0) + direction * cfg.cast_offset_from_body_m


func _configure_character_physics() -> void:
	if physics_settings == null:
		return
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up_direction = Vector3.UP
	floor_snap_length = physics_settings.floor_snap_length_m
	floor_max_angle = deg_to_rad(physics_settings.floor_max_angle_deg)
	floor_stop_on_slope = physics_settings.floor_stop_on_slope


func _apply_gravity(delta: float) -> void:
	if physics_settings == null:
		return
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = physics_settings.floor_stick_down_mps
		return
	velocity.y -= physics_settings.get_gravity_mps2() * delta
	velocity.y = maxf(velocity.y, -physics_settings.max_fall_speed_mps)


func _get_floor_aligned_move_direction(wish_dir: Vector3) -> Vector3:
	if wish_dir.length_squared() < 0.0001:
		return Vector3.ZERO
	if physics_settings != null and physics_settings.slide_along_floor and is_on_floor():
		return wish_dir.slide(get_floor_normal())
	return wish_dir


func _setup_footstep_audio() -> void:
	_footstep_player = AudioStreamPlayer3D.new()
	_footstep_player.name = "FootstepAudio"
	_footstep_player.max_distance = 48.0
	add_child(_footstep_player)
	_action_audio = AudioStreamPlayer3D.new()
	_action_audio.name = "ActionAudio"
	_action_audio.max_distance = 48.0
	add_child(_action_audio)


func _play_action_sound(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> void:
	if stream == null or _action_audio == null:
		return
	_action_audio.stream = stream
	_action_audio.volume_db = volume_db
	_action_audio.pitch_scale = pitch_scale
	_action_audio.play()


func _play_pickup_sound(item_data: ItemData) -> void:
	if _action_audio == null:
		return
	if item_data != null and item_data.pickup_sound != null:
		var item_clip: AudioClipSettings = AudioClipSettings.from_stream(item_data.pickup_sound)
		item_clip.play_on(_action_audio, 0.0, 1.0)
		return
	if footstep_settings == null or footstep_settings.pickup_clip == null:
		return
	footstep_settings.pickup_clip.play_on(
		_action_audio,
		footstep_settings.pickup_volume_db,
		1.0
	)


func _stop_footstep_sound() -> void:
	_footstep_cooldown_sec = 0.0
	_footstep_distance_m = 0.0
	_footstep_had_move_input = false
	if _footstep_player != null and _footstep_player.playing:
		_footstep_player.stop()


func _is_grounded_for_footsteps() -> bool:
	return is_on_floor()


func _play_footstep_step(is_running: bool, speed_horizontal: float) -> void:
	if footstep_settings == null or _footstep_player == null:
		return
	if _footstep_player.playing or _footstep_cooldown_sec > 0.0:
		return
	var surface_id := ""
	var clip: AudioClipSettings = footstep_settings.get_step_clip_for_surface(surface_id)
	if clip == null:
		return
	clip.play_on(
		_footstep_player,
		footstep_settings.get_volume_db_for_surface(surface_id, is_running),
		footstep_settings.get_pitch_scale(is_running)
	)
	_footstep_distance_m = 0.0
	_footstep_cooldown_sec = footstep_settings.get_min_step_interval_sec(
		is_running,
		maxf(speed_horizontal, 1.0),
		surface_id
	)


func _update_footsteps(
	delta: float,
	is_moving: bool,
	is_running: bool,
	has_move_input: bool
) -> void:
	if footstep_settings == null or not footstep_settings.has_step_audio():
		_stop_footstep_sound()
		return
	if _footstep_player == null:
		return
	if not has_move_input:
		_stop_footstep_sound()
		return
	if _movement_locked:
		return
	if not is_moving:
		_stop_footstep_sound()
		return
	if not _is_grounded_for_footsteps():
		_stop_footstep_sound()
		return

	var speed_horizontal := Vector2(velocity.x, velocity.z).length()

	if _footstep_cooldown_sec > 0.0:
		_footstep_cooldown_sec = maxf(_footstep_cooldown_sec - delta, 0.0)

	var just_started_moving := has_move_input and not _footstep_had_move_input
	_footstep_had_move_input = true

	if just_started_moving:
		_play_footstep_step(is_running, maxf(speed_horizontal, 1.0))
		return

	if speed_horizontal < footstep_settings.min_speed_for_steps_mps:
		return

	if _footstep_cooldown_sec > 0.0:
		return

	var step_distance := footstep_settings.get_step_distance_m(is_running)
	_footstep_distance_m += speed_horizontal * delta
	if _footstep_distance_m < step_distance:
		return
	_play_footstep_step(is_running, speed_horizontal)


func _get_cursor_point_on_ground() -> Vector3:
	if camera == null:
		return NO_GROUND_HIT
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var ground_plane := Plane(Vector3.UP, global_position.y)
	var hit: Variant = ground_plane.intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return NO_GROUND_HIT
	return hit as Vector3


func _cursor_hits_ground(ground_point: Vector3) -> bool:
	return ground_point.is_finite()


func _get_aim_direction_from_cursor() -> Vector3:
	var ground_point := _get_cursor_point_on_ground()
	if not _cursor_hits_ground(ground_point):
		return _get_flat_forward()
	var to_target := ground_point - global_position
	to_target.y = 0.0
	if to_target.length_squared() < SPELL_AIM_MIN_DISTANCE_SQ:
		return _get_flat_forward()
	return to_target.normalized()


func _try_dash() -> void:
	if dash_settings == null:
		return
	if _movement_locked:
		return
	if Time.get_ticks_msec() < _next_dash_allowed_msec:
		return
	if stats_component == null or stats_component.stats == null:
		return
	if stats_component.stats.energy < dash_settings.energy_cost:
		return
	var move_dir := direction
	if move_dir.length_squared() < 0.01:
		move_dir = _get_flat_forward()
	else:
		move_dir = move_dir.normalized()
	var from_pos := global_position
	var to_pos := _resolve_dash_end_position(from_pos, move_dir, dash_settings.distance)
	DashVfx.play(from_pos, to_pos, dash_settings)
	global_position = to_pos
	velocity = Vector3(move_dir.x, 0.0, move_dir.z) * dash_settings.distance * 0.5
	apply_floor_snap()
	stats_component.stats.energy = maxf(
		stats_component.stats.energy - dash_settings.energy_cost,
		0.0
	)
	_next_dash_allowed_msec = Time.get_ticks_msec() + int(dash_settings.cooldown_sec * 1000.0)
	_movement_locked = true
	await get_tree().create_timer(dash_settings.movement_lock_sec).timeout
	if is_instance_valid(self) and not _is_dead:
		_movement_locked = false
	SaveManager.mark_unsaved_changes()


func _resolve_dash_end_position(from_pos: Vector3, move_dir: Vector3, distance: float) -> Vector3:
	var target := from_pos + move_dir * distance
	target = _clamp_dash_against_walls(from_pos, target, move_dir)
	target.y = _resolve_dash_ground_y(from_pos, target)
	if _is_dash_capsule_blocked(target):
		target = _find_last_clear_dash_position(from_pos, target, move_dir)
		target.y = _resolve_dash_ground_y(from_pos, target)
	return target


func _clamp_dash_against_walls(from_pos: Vector3, to_pos: Vector3, move_dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return to_pos
	var chest_height := _get_dash_probe_height()
	var query := PhysicsRayQueryParameters3D.create(
		from_pos + Vector3(0.0, chest_height, 0.0),
		to_pos + Vector3(0.0, chest_height, 0.0)
	)
	query.exclude = [get_rid()]
	query.collision_mask = dash_settings.collision_mask
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return to_pos
	var hit_pos: Vector3 = hit.position
	return hit_pos - move_dir * dash_settings.wall_stop_padding


func _resolve_dash_ground_y(from_pos: Vector3, target: Vector3) -> float:
	var ground_y := _sample_ground_y(target.x, target.z, from_pos.y)
	return clampf(
		ground_y,
		from_pos.y - dash_settings.max_drop_m,
		from_pos.y + dash_settings.max_step_up_m
	)


func _sample_ground_y(x: float, z: float, reference_y: float) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return reference_y
	var origin := Vector3(x, reference_y + dash_settings.ground_probe_up_m, z)
	var end := Vector3(x, reference_y - dash_settings.ground_probe_down_m, z)
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	query.collision_mask = dash_settings.ground_collision_mask
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return reference_y
	var normal: Vector3 = hit.normal
	if normal.y < dash_settings.floor_normal_min_y:
		return reference_y
	return hit.position.y


func _get_dash_probe_height() -> float:
	var col := $CollisionShape3D as CollisionShape3D
	if col != null:
		return col.position.y
	return 0.85


func _is_dash_capsule_blocked(world_pos: Vector3) -> bool:
	var col := $CollisionShape3D as CollisionShape3D
	if col == null or col.shape == null:
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = col.shape
	var xf := global_transform
	xf.origin = world_pos
	params.transform = xf * col.transform
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return space.intersect_shape(params, 1).size() > 0


func _find_last_clear_dash_position(from_pos: Vector3, to_pos: Vector3, move_dir: Vector3) -> Vector3:
	var delta := to_pos - from_pos
	delta.y = 0.0
	if delta.length_squared() < 0.0001:
		return from_pos
	var steps := 8
	for step_index in range(steps, 0, -1):
		var t := float(step_index) / float(steps)
		var candidate := from_pos + delta * t
		if not _is_dash_capsule_blocked(candidate):
			return candidate
	return from_pos


func _apply_tool_ray_hit(item: ItemData) -> bool:
	if interact_ray == null:
		return false
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		return false
	var collider: Object = interact_ray.get_collider()
	if collider == null:
		return false

	var harvestable := _find_harvestable_from_collider(collider)
	if harvestable != null:
		return harvestable.try_harvest(self)

	var target := _resolve_damage_target(collider as Node)
	if target == null or not target.has_method("take_damage"):
		return false
	var dmg: float = item.entity_damage if item.entity_damage > 0.0 else 1.0
	target.call("take_damage", dmg, self)
	return true


func _apply_sword_arc_hit(item: ItemData) -> bool:
	var forward := _get_flat_forward()
	var origin := global_position + Vector3(0.0, item.melee_arc_height, 0.0)
	_play_action_sound(item.weapon_hit_sound, item.weapon_hit_volume_db)
	_spawn_sword_slash_vfx(origin, forward, item)
	var targets := MeleeArcHit.collect_damage_targets(
		self,
		origin,
		forward,
		item.melee_arc_reach,
		item.melee_arc_radius,
		item.melee_arc_angle_deg,
		item.melee_arc_hit_samples,
		MeleeArcHit.DEFAULT_MASK,
		item.melee_arc_hit_center_ratio
	)
	var dmg: float = item.entity_damage if item.entity_damage > 0.0 else 1.0
	var hit_any := false
	for target in targets:
		if is_instance_valid(target):
			target.call("take_damage", dmg, self)
			hit_any = true
	return hit_any


func _get_flat_forward() -> Vector3:
	# Совпадает с поворотом к курсору (atan2 x,z → ось +Z персонажа).
	var f := global_transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()
	return f.normalized()


func _spawn_sword_slash_vfx(origin: Vector3, forward: Vector3, item: ItemData) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var vfx := SWORD_SLASH_VFX_SCENE.instantiate() as SwordSlashVfx
	if vfx == null:
		return
	root.add_child(vfx)
	vfx.play(
		origin,
		forward,
		item.melee_arc_reach,
		item.melee_arc_angle_deg,
		item.get_slash_vfx()
	)


func take_damage(amount: float, source: Node = null) -> void:
	take_damage_info(DamageInfo.from_amount(amount, source))


func take_damage_info(info: DamageInfo) -> void:
	if _is_dead or info == null or stats_component == null or stats_component.stats == null:
		return
	var dmg := maxf(info.amount, 0.0)
	if dmg <= 0.0:
		return
	stats_component.stats.health = maxf(stats_component.stats.health - dmg, 0.0)


func _find_harvestable_from_collider(collider: Object) -> Node:
	var node := collider as Node
	while node != null:
		if node.has_method("try_harvest"):
			return node
		node = node.get_parent()
	return null


func _resolve_damage_target(collider: Node) -> Node:
	if collider == null:
		return null
	if collider.has_method("take_damage"):
		return collider
	var parent := collider.get_parent()
	if parent != null and parent.has_method("take_damage"):
		return parent
	return null


func _get_closest_nearby_dropped_item() -> DroppedItem:
	if nearby_dropped_items.is_empty():
		return null
	var closest: DroppedItem = null
	var best_d2 := INF
	for item in nearby_dropped_items:
		if not is_instance_valid(item):
			continue
		var d2 := global_position.distance_squared_to(item.global_position)
		if d2 < best_d2:
			best_d2 = d2
			closest = item
	return closest


func _pickup_closest_dropped_item() -> void:
	var closest := _get_closest_nearby_dropped_item()
	if closest != null and closest.pickup():
		_play_pickup_sound(closest.item_data)


func update_equipped_tool_from_hotbar() -> void:
	equipped_slot_index = hotbar_ui.active_slot_index if hotbar_ui else -1
	if not hotbar_ui or hotbar_ui.active_slot_index < 0:
		tool_equipper.clear_tool()
		return

	var stack := hotbar_inventory.get_slot(hotbar_ui.active_slot_index)
	if stack and stack.item and stack.item.is_magic_sphere() and stack.item.magic_hide_hand_model:
		tool_equipper.clear_tool()
		return
	if stack and stack.item and stack.item.is_equippable and _stack_has_durability_left(stack):
		tool_equipper.equip_tool(stack.item)
	else:
		tool_equipper.clear_tool()


func _get_equipped_hotbar_stack() -> ItemStack:
	if hotbar_ui == null or hotbar_inventory == null:
		return null
	if hotbar_ui.active_slot_index < 0:
		return null
	return hotbar_inventory.get_slot(hotbar_ui.active_slot_index)


func _stack_has_durability_left(stack: ItemStack) -> bool:
	if stack == null:
		return false
	if not stack.uses_durability():
		return true
	return stack.durability > 0


func _has_equipped_tool_durability() -> bool:
	var stack := _get_equipped_hotbar_stack()
	return _stack_has_durability_left(stack)


func _apply_equipped_tool_wear() -> void:
	var slot_idx := hotbar_ui.active_slot_index if hotbar_ui else -1
	if slot_idx < 0 or hotbar_inventory == null:
		return
	var stack := hotbar_inventory.get_slot(slot_idx)
	if stack == null or stack.item == null or not stack.uses_durability():
		return
	var loss := maxi(stack.item.durability_loss_per_use, 1)
	if stack.apply_wear(loss):
		_on_equipped_tool_broken(slot_idx, stack.item)
	hotbar_inventory.changed.emit()
	if hotbar_ui:
		hotbar_ui.refresh_slots()


func _on_equipped_tool_broken(slot_idx: int, item: ItemData) -> void:
	hotbar_inventory.clear_slot(slot_idx)
	tool_equipper.clear_tool()
	var name_str := item.display_name if item else "Инструмент"
	print("%s сломался!" % name_str)


func apply_consumable_from_hotbar(slot_index: int):
	if slot_index < 0 or slot_index >= hotbar_inventory.slots_count:
		return
	
	var stack = hotbar_inventory.get_slot(slot_index)
	if not stack or not stack.item or not stack.item.is_consumable:
		return

	var stats_comp = stats_component
	if not stats_comp:
		return

	stats_comp.apply_item_effects(stack.item)

	# Уменьшаем стак
	if stack.count > 1:
		stack.count -= 1
	else:
		hotbar_inventory.clear_slot(slot_index)

	hotbar_inventory.changed.emit()
	print("Применено с hotbar (слот", slot_index + 1, "):", stack.item.display_name)



func close_all_ui():
	for node in get_tree().get_nodes_in_group("persist_chest"):
		if node is Chest:
			(node as Chest).close_if_open()

	var all_uis = get_tree().get_nodes_in_group("inventory_ui")
	for ui in all_uis:
		if is_instance_valid(ui):
			ui.queue_free()

	if current_inventory_ui and is_instance_valid(current_inventory_ui):
		current_inventory_ui.queue_free()
		current_inventory_ui = null

	if current_equipment_panel and is_instance_valid(current_equipment_panel):
		current_equipment_panel.queue_free()
		current_equipment_panel = null
	
	if current_stats_summary_panel and is_instance_valid(current_stats_summary_panel):
		current_stats_summary_panel.queue_free()
		current_stats_summary_panel = null

	if current_crafting_ui and is_instance_valid(current_crafting_ui):
		current_crafting_ui.queue_free()
		current_crafting_ui = null


func open_crafting_ui(station_type: CraftingStationType = null, station: CraftingStation = null) -> void:
	# Открываем так, чтобы окна не накладывались.
	close_all_ui()
	
	var ui = preload("res://scenes/ui/crafting/crafting_ui.tscn").instantiate()
	if ui is CraftingUI:
		(ui as CraftingUI).setup(self, inventory, station_type, [hotbar_inventory], station)
	ui.add_to_group("inventory_ui")
	$UI_Layer.add_child(ui)
	current_crafting_ui = ui
	current_crafting_station = station
	
	# Если это станция — открываем окно выхода + инвентарь игрока (как сундук).
	if station != null and is_instance_valid(station) and station.has_method("get_output_inventory"):
		var out_inv: Inventory = station.get_output_inventory()
		if out_inv != null:
			var out_ui = preload("res://scenes/inventory/universal_inventory.tscn").instantiate()
			out_ui.inventory = out_inv
			out_ui.title = "Выход"
			out_ui.columns = 3
			out_ui.placement = "LEFT"
			out_ui.take_only = true
			out_ui.show_close_button = false
			out_ui.add_to_group("inventory_ui")
			get_tree().current_scene.add_child(out_ui)
			
			var player_ui = preload("res://scenes/inventory/universal_inventory.tscn").instantiate()
			player_ui.inventory = inventory
			player_ui.title = "Инвентарь"
			player_ui.columns = 6
			player_ui.placement = "RIGHT"
			player_ui.show_close_button = false
			player_ui.add_to_group("inventory_ui")
			get_tree().current_scene.add_child(player_ui)


func _try_interact_raycast() -> void:
	if interact_ray == null:
		return
	if not interact_ray.is_colliding():
		return

	var collider := interact_ray.get_collider()
	if collider == null:
		return

	# collider может быть CollisionObject3D, а скрипт висит на родителе
	var target: Node = collider
	if not target.has_method("interact") and target.get_parent() != null and target.get_parent().has_method("interact"):
		target = target.get_parent()
	
	if target.has_method("interact"):
		target.interact(self)


func register_interactable(obj: Node3D) -> void:
	if obj == null:
		return
	if not _nearby_interactables.has(obj):
		_nearby_interactables.append(obj)
	_update_active_interactable()


func unregister_interactable(obj: Node3D) -> void:
	if obj == null:
		return
	_nearby_interactables.erase(obj)
	if _active_interactable == obj:
		_active_interactable = null
	_update_active_interactable()
	
	# Если отошли от станции, с которой открыт крафт — закрываем окно.
	if current_crafting_station != null and obj == current_crafting_station:
		close_all_ui()
		current_crafting_station = null


func _update_active_interactable() -> void:
	# Выбираем ближайший валидный объект.
	var best: Node3D = null
	var best_d2 := INF
	for obj in _nearby_interactables:
		if obj == null or not is_instance_valid(obj):
			continue
		var d2 := global_position.distance_squared_to(obj.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = obj
	_active_interactable = best


func _update_interaction_prompt() -> void:
	if _interaction_prompt == null or not is_instance_valid(_interaction_prompt):
		return
	
	_update_active_interactable()

	var dropped := _get_closest_nearby_dropped_item()
	if dropped != null:
		_interaction_prompt.set_text(dropped.get_pickup_prompt_text())
		var drop_pos := dropped.get_prompt_world_position()
		if camera == null:
			_interaction_prompt.set_visible_prompt(false)
			return
		if camera.has_method("is_world_point_behind_camera") and camera.is_world_point_behind_camera(drop_pos):
			_interaction_prompt.set_visible_prompt(false)
			return
		var drop_screen := camera.unproject_position(drop_pos)
		_interaction_prompt.set_screen_position(drop_screen + Vector2(-80, -30))
		_interaction_prompt.set_visible_prompt(true)
		return

	if _active_interactable == null:
		_interaction_prompt.set_visible_prompt(false)
		return

	var text := "Нажмите %s: Взаимодействие" % "E"
	if _active_interactable.has_method("get_interaction_text"):
		text = "Нажмите %s: %s" % ["E", _active_interactable.get_interaction_text()]
	_interaction_prompt.set_text(text)

	var world_pos: Vector3 = _active_interactable.global_position
	if _active_interactable.has_method("get_prompt_world_position"):
		world_pos = _active_interactable.get_prompt_world_position()
	
	if camera == null:
		_interaction_prompt.set_visible_prompt(false)
		return
	
	var screen := camera.unproject_position(world_pos)
	# Простая отсечка "за камерой"
	if camera.has_method("is_world_point_behind_camera") and camera.is_world_point_behind_camera(world_pos):
		_interaction_prompt.set_visible_prompt(false)
		return
	
	_interaction_prompt.set_screen_position(screen + Vector2(-80, -30))
	_interaction_prompt.set_visible_prompt(true)
