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

@onready var anim_tree: AnimationTree = $PlayerAnimTree
@onready var interact_ray: RayCast3D = $InteractRay


var current_inventory_ui: Control = null
@onready var inventory: Inventory = $Inventory
@onready var ui_layer: CanvasLayer = $UI_Layer

@onready var inventory_ui_scene: PackedScene = preload("res://scenes/inventory/universal_inventory.tscn")


var nearby_dropped_items: Array[DroppedItem] = []
var direction: Vector3 = Vector3.ZERO
var last_moving: bool = false
var last_running: bool = false
var is_tree_chopping_now: bool = false

func _ready() -> void:
	anim_tree.active = true
	await get_tree().process_frame
	await get_tree().process_frame
	
	inventory.item_dropped.connect(_on_item_dropped)
	
	var harvestables = get_tree().get_nodes_in_group("harvestable")
	print("Найдено harvestable: ", harvestables.size())
	for h in harvestables:
		if h.has_signal("harvested"):
			if not h.harvested.is_connected(_on_harvested):
				h.harvested.connect(_on_harvested)
				print("Подключил harvested к ", h.name)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		# Если открыт любой сундук — НЕ открываем инвентарь, а закрываем всё
		var all_uis = get_tree().get_nodes_in_group("inventory_ui")
		var has_chest = false
		for ui in all_uis:
			if ui.title == "Сундук" and is_instance_valid(ui):
				has_chest = true
				break
		
		if has_chest:
			# Закрываем все окна сундука и игрока
			for ui in all_uis:
				if is_instance_valid(ui):
					ui.queue_free()
			current_inventory_ui = null
			print("Сундук открыт — закрываем все окна")
			return
		
		# Обычное открытие/закрытие инвентаря игрока
		if current_inventory_ui and is_instance_valid(current_inventory_ui):
			current_inventory_ui.queue_free()
			current_inventory_ui = null
			print("Инвентарь закрыт")
		else:
			var ui = preload("res://scenes/inventory/universal_inventory.tscn").instantiate()
			ui.inventory = $Inventory
			ui.title = "Инвентарь"
			ui.columns = 6
			ui.add_to_group("inventory_ui")  # ← группа для поиска
			$UI_Layer.add_child(ui)
			current_inventory_ui = ui
			print("Инвентарь открыт")
	elif event.is_action_pressed("ui_cancel"):
		# Esc — закрываем всё, что открыто
		var all_uis = get_tree().get_nodes_in_group("inventory_ui")
		for ui in all_uis:
			if is_instance_valid(ui):
				ui.queue_free()
		current_inventory_ui = null
		print("Esc — все окна закрыты")
	

func _physics_process(delta: float) -> void:
	if camera == null: return
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var is_running = Input.is_action_pressed("run")
	var wants_to_move = input_dir.length() > 0.05
	
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
	
	var preset = run_preset if is_running and wants_to_move else walk_preset
	var target_vel = direction * preset.max_speed
	
	if wants_to_move:
		var forward_component = velocity.dot(direction.normalized())
		forward_component = max(0, forward_component)
		var perp = velocity - direction.normalized() * forward_component
		perp = perp.move_toward(Vector3.ZERO, 60.0 * delta)
		
		velocity = direction * forward_component + direction * (preset.max_speed / preset.acceleration_time) * delta
		
		if velocity.length() > preset.max_speed:
			velocity = velocity.normalized() * preset.max_speed
		
		# ←←← ИСПРАВЛЕНИЕ: поворот по направлению движения ТОЛЬКО при беге
		if is_running and direction.length() > 0.01:
			var move_angle = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, move_angle, 12.0 * delta)
	
	else:
		var decel = preset.max_speed / preset.deceleration_time
		if last_running:
			decel *= run_deceleration_multiplier
		velocity = velocity.move_toward(Vector3.ZERO, decel * delta)
	
	move_and_slide()
	
	# Условия анимации
	var is_moving_now = direction.length() > 0.1 and wants_to_move
	var is_running_now = is_running and is_moving_now
	
	last_moving = is_moving_now
	last_running = is_running_now
	
	is_tree_chopping_now = Input.is_action_just_pressed("attack")
	
	if is_tree_chopping_now:
		# Поворот к курсору при рубке (мгновенный)
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_dir = camera.project_ray_normal(mouse_pos)
		var plane = Plane(Vector3.UP, global_position.y)
		var intersection = plane.intersects_ray(ray_origin, ray_dir)
		if intersection:
			var look_dir = (intersection - global_position).normalized()
			look_dir.y = 0
			if look_dir.length() > 0.01:
				var target_angle = atan2(look_dir.x, look_dir.z)
				rotation.y = target_angle
	
	if anim_tree:
		anim_tree.set("parameters/conditions/is_moving", is_moving_now)
		anim_tree.set("parameters/conditions/is_running", is_running_now)
		anim_tree.set("parameters/conditions/is_not_moving", not is_moving_now)
		anim_tree.set("parameters/conditions/is_not_running", not is_running_now)
		anim_tree.set("parameters/conditions/is_tree_chopping", is_tree_chopping_now)
	
	# Взаимодействие (без изменений)
	if Input.is_action_just_pressed("attack"):
		if interact_ray.is_colliding():
			var collider = interact_ray.get_collider()
			print("Попал в объект: ", collider.name, " | путь: ", collider.get_path())
			if collider.has_method("try_harvest"):
				var success = collider.try_harvest(self)
				if success:
					print("Успешно собрано!")
			else:
				print("Raycast ничего не видит!")
	
	if Input.is_action_just_pressed("interact"):
		if nearby_dropped_items.size() > 0:
			var closest = nearby_dropped_items[0]
			for item in nearby_dropped_items:
				var dist = global_position.distance_to(item.global_position)
				var closest_dist = global_position.distance_to(closest.global_position)
				if dist < closest_dist:
					closest = item
			closest.pickup()
			print("Подобрано ближайший предмет: ", closest.item_data.display_name)
		else:
			print("Нет предметов в зоне")

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
