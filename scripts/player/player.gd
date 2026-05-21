class_name Player
extends CharacterBody3D

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

func _ready() -> void:
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
	if Input.is_action_just_pressed("ui_accept"): # клавиша Enter для теста
		var test_item = preload("res://resources/items/axe_wood.tres")
		if test_item:
			tool_equipper.equip_tool(test_item)
			print("Тест: пытаемся экипировать кирку")

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
		velocity = velocity.move_toward(Vector3.ZERO, 12.0 * delta)
		move_and_slide()
		return

	var input_dir := Vector2.ZERO
	if not _movement_locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var energy_ok := stats_component != null and stats_component.stats != null and stats_component.stats.energy > 0.0
	var is_running := Input.is_action_pressed("run") and energy_ok
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
		
		var plane = Plane(Vector3.UP, global_position.y)
		var intersection = plane.intersects_ray(ray_origin, ray_dir)
		
		if intersection:
			var look_at_point = intersection
			look_at_point.y = global_position.y
			
			var look_dir = (look_at_point - global_position).normalized()
			look_dir.y = 0
			
			if look_dir.length() > 0.01:   # защита от деления на ноль / дрожания под ногами
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
	var target_vel := direction * speed_cap
	
	if wants_to_move:
		var forward_component = velocity.dot(direction.normalized())
		forward_component = max(0, forward_component)
		var perp = velocity - direction.normalized() * forward_component
		perp = perp.move_toward(Vector3.ZERO, 60.0 * delta)
		
		velocity = direction * forward_component + direction * (speed_cap / preset.acceleration_time) * delta

		if velocity.length() > speed_cap:
			velocity = velocity.normalized() * speed_cap
		
		# ←←← ИСПРАВЛЕНИЕ: поворот по направлению движения ТОЛЬКО при беге
		if is_running and direction.length() > 0.01:
			var move_angle = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, move_angle, 12.0 * delta)
	
	else:
		var decel = speed_cap / preset.deceleration_time
		if last_running:
			decel *= run_deceleration_multiplier
		velocity = velocity.move_toward(Vector3.ZERO, decel * delta)
	
	move_and_slide()
	_update_interaction_prompt()
	
	# Условия анимации
	var is_moving_now = direction.length() > 0.1 and wants_to_move
	var is_running_now = is_running and is_moving_now
	
	last_moving = is_moving_now
	last_running = is_running_now
	
	if anim_tree and anim_tree.active:
		anim_tree.set("parameters/conditions/is_moving", is_moving_now)
		anim_tree.set("parameters/conditions/is_running", is_running_now)
		anim_tree.set("parameters/conditions/is_not_moving", not is_moving_now)
		anim_tree.set("parameters/conditions/is_not_running", not is_running_now)
		anim_tree.set("parameters/conditions/is_tree_chopping", false)
	
	if Input.is_action_just_pressed("attack") and not _movement_locked:
		_try_start_attack_action()
	
	if Input.is_action_just_pressed("interact") and not _movement_locked:
		if nearby_dropped_items.size() > 0:
			_try_start_pickup_action()

func _on_harvested(drops: Array[Dictionary]) -> void:
	print("Дерево срублено! Выпало предметов на землю: ", drops.size())
	# НИЧЕГО не добавляем в инвентарь здесь!
	# Предметы уже выпали на землю через harvestable/tree_basic
	# Добавление будет ТОЛЬКО при нажатии E (в DroppedItem.pickup())


func _on_item_dropped(stack: ItemStack, total_drop: int, spawn_pos: Vector3, look_dir: Vector3) -> void:
	for i in total_drop:
		var offset = Vector3(randf_range(-0.6, 0.6), randf_range(-0.2, 0.4), randf_range(-0.6, 0.6))
		var final_pos = spawn_pos + offset
		
		var dropped = preload("res://scenes/world_objects/dropped_item/dropped_item.tscn").instantiate()
		
		dropped.item_data = stack.item
		dropped.count = 1
		
		get_tree().current_scene.add_child(dropped)
		
		dropped.global_position = final_pos
		
		var rb = dropped.get_node_or_null("RigidBody3D")
		if rb:
			rb.apply_central_impulse(look_dir * 4.0 + Vector3(0, 2.0, 0))
		
		print("Выброшен 1 предмет: ", stack.item.display_name, " на ", final_pos)

func get_equipped_item_data() -> ItemData:
	if tool_equipper == null or tool_equipper.current_tool == null:
		return null
	if tool_equipper.current_tool.has_meta("item_data"):
		return tool_equipper.current_tool.get_meta("item_data") as ItemData
	return null


func _face_cursor_instant() -> void:
	if camera == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var plane := Plane(Vector3.UP, global_position.y)
	var intersection: Variant = plane.intersects_ray(ray_origin, ray_dir)
	if intersection == null:
		return
	var look_dir: Vector3 = (intersection as Vector3 - global_position).normalized()
	look_dir.y = 0.0
	if look_dir.length() > 0.01:
		rotation.y = atan2(look_dir.x, look_dir.z)


func _try_start_attack_action() -> void:
	if _action_animator == null or _action_animator.is_busy():
		return
	var item := get_equipped_item_data()
	if item == null or not item.can_primary_action():
		return
	_face_cursor_instant()
	if _action_animator.play_item_action(item):
		_movement_locked = true


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
	_apply_primary_action_hit()
	# После кадра удара можно уходить с линии атаки (остаток клипа доигрывается).
	_movement_locked = false


func _on_action_recovery() -> void:
	_movement_locked = false


func _on_action_anim_finished(kind: String) -> void:
	if kind != "death":
		_movement_locked = false
	if kind == "pickup" and _pending_pickup:
		_pending_pickup = false
		_pickup_closest_dropped_item()


func _apply_primary_action_hit() -> void:
	var item := get_equipped_item_data()
	if item == null:
		return
	if item.uses_melee_arc_hit():
		_apply_sword_arc_hit(item)
	else:
		_apply_tool_ray_hit(item)


func _apply_tool_ray_hit(item: ItemData) -> void:
	if interact_ray == null:
		return
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		return
	var collider: Object = interact_ray.get_collider()
	if collider == null:
		return

	var harvestable := _find_harvestable_from_collider(collider)
	if harvestable != null:
		harvestable.try_harvest(self)
		return

	var target := _resolve_damage_target(collider as Node)
	if target == null or not target.has_method("take_damage"):
		return
	var dmg: float = item.entity_damage if item.entity_damage > 0.0 else 1.0
	target.call("take_damage", dmg, self)


func _apply_sword_arc_hit(item: ItemData) -> void:
	var forward := _get_flat_forward()
	var origin := global_position + Vector3(0.0, item.melee_arc_height, 0.0)
	_spawn_sword_slash_vfx(origin, forward, item)
	var targets := MeleeArcHit.collect_damage_targets(
		self,
		origin,
		forward,
		item.melee_arc_reach,
		item.melee_arc_radius,
		item.melee_arc_angle_deg
	)
	var dmg: float = item.entity_damage if item.entity_damage > 0.0 else 1.0
	for target in targets:
		if is_instance_valid(target):
			target.call("take_damage", dmg, self)


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
	vfx.play(origin, forward, item.melee_arc_reach, item.melee_arc_angle_deg)


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


func _pickup_closest_dropped_item() -> void:
	if nearby_dropped_items.is_empty():
		return
	var closest: DroppedItem = nearby_dropped_items[0]
	for item in nearby_dropped_items:
		if not is_instance_valid(item):
			continue
		if global_position.distance_to(item.global_position) < global_position.distance_to(closest.global_position):
			closest = item
	if is_instance_valid(closest):
		closest.pickup()


func update_equipped_tool_from_hotbar():
	if not hotbar_ui or hotbar_ui.active_slot_index < 0:
		tool_equipper.clear_tool()
		return

	var stack = hotbar_inventory.get_slot(hotbar_ui.active_slot_index)
	
	if stack and stack.item and stack.item.is_equippable:
		tool_equipper.equip_tool(stack.item)
	else:
		tool_equipper.clear_tool()


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
	
	if _active_interactable == null or nearby_dropped_items.size() > 0:
		_interaction_prompt.set_visible_prompt(false)
		return
	
	var text := "Нажмите %s: Взаимодействие" % "E"
	if _active_interactable.has_method("get_interaction_text"):
		text = "Нажмите %s: %s" % ["E", _active_interactable.get_interaction_text()]
	_interaction_prompt.set_text(text)
	
	# World -> Screen позиция
	var world_pos: Vector3 = _active_interactable.global_position
	if _active_interactable.has_method("get_prompt_world_position"):
		world_pos = _active_interactable.get_prompt_world_position()
	
	if camera == null:
		_interaction_prompt.set_visible_prompt(false)
		return
	
	var screen := camera.unproject_position(world_pos)
	# Простая отсечка "за камерой"
	if camera.is_position_behind(world_pos):
		_interaction_prompt.set_visible_prompt(false)
		return
	
	_interaction_prompt.set_screen_position(screen + Vector2(-80, -30))
	_interaction_prompt.set_visible_prompt(true)
