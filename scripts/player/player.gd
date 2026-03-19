class_name Player
extends CharacterBody3D

# Настройки
@export var camera: Camera3D
@export var walk_preset: MovementPreset
@export var run_preset: MovementPreset
@export var conditions: PlayerConditions
@export var run_deceleration_multiplier: float = 2.0
@export var mouse_look_speed: float = 10.0   # скорость поворота по мыши

@onready var anim_tree: AnimationTree = $PlayerAnimTree

var direction: Vector3 = Vector3.ZERO
var last_moving: bool = false
var last_running: bool = false

func _ready() -> void:
	anim_tree.active = true
	await get_tree().process_frame
	await get_tree().process_frame

func _physics_process(delta: float) -> void:
	if camera == null: return

	# ────────────────────────────────────────────────
	# Поворот по мыши — только когда стоим или зажата attack
	# ────────────────────────────────────────────────
	if Input.is_action_pressed("attack"):
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_dir = camera.project_ray_normal(mouse_pos)

		# Пересечение с плоскостью на уровне персонажа
		var plane = Plane(Vector3.UP, global_position.y)
		var intersection = plane.intersects_ray(ray_origin, ray_dir)

		if intersection:
			var look_at_point = intersection
			look_at_point.y = global_position.y  # фиксируем высоту

			var look_dir = (look_at_point - global_position).normalized()
			look_dir.y = 0

			if look_dir.length() > 0.01:
				var target_angle = atan2(look_dir.x, look_dir.z)
				rotation.y = target_angle  # мгновенный поворот (без lerp для атаки)

	# ────────────────────────────────────────────────
	# Движение и поворот по направлению (твой оригинальный код)
	# ────────────────────────────────────────────────
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_forward = camera.global_transform.basis.z.normalized()
	cam_forward.y = 0
	var cam_right = camera.global_transform.basis.x.normalized()
	cam_right.y = 0
	direction = (cam_right * input_dir.x + cam_forward * input_dir.y).normalized()

	var preset = run_preset if Input.is_action_pressed("run") and direction.length() > 0.1 else walk_preset

	var target_vel = direction * preset.max_speed

	if direction != Vector3.ZERO:
		var forward_component = velocity.dot(direction.normalized())
		forward_component = max(0, forward_component)

		var perp = velocity - direction.normalized() * forward_component
		perp = perp.move_toward(Vector3.ZERO, 60.0 * delta)

		velocity = direction * forward_component + direction * (preset.max_speed / preset.acceleration_time) * delta

		if velocity.length() > preset.max_speed:
			velocity = velocity.normalized() * preset.max_speed

		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 12.0 * delta)
	else:
		var decel = preset.max_speed / preset.deceleration_time
		if last_running:
			decel *= run_deceleration_multiplier
		velocity = velocity.move_toward(Vector3.ZERO, decel * delta)

	move_and_slide()

	# Условия анимации
	var is_moving_now = direction.length() > 0.1
	var is_running_now = Input.is_action_pressed("run") and is_moving_now
	var is_not_moving_now = not is_moving_now
	var is_not_running_now = not is_running_now

	if anim_tree:
		anim_tree.set("parameters/conditions/is_moving", is_moving_now)
		anim_tree.set("parameters/conditions/is_running", is_running_now)
		anim_tree.set("parameters/conditions/is_not_moving", is_not_moving_now)
		anim_tree.set("parameters/conditions/is_not_running", is_not_running_now)

	# Отладка
	print("is_moving: ", is_moving_now, " | is_running: ", is_running_now)
	print("is_not_moving: ", is_not_moving_now, " | is_not_running: ", is_not_running_now)
