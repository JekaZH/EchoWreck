class_name Player
extends CharacterBody3D

# Настройки
@export var camera: Camera3D
@export var walk_preset: MovementPreset
@export var run_preset: MovementPreset
@export var conditions: PlayerConditions

@export var run_deceleration_multiplier: float = 2.0

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

	# Ввод
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_forward = camera.global_transform.basis.z.normalized()
	cam_forward.y = 0
	var cam_right = camera.global_transform.basis.x.normalized()
	cam_right.y = 0
	direction = (cam_right * input_dir.x + cam_forward * input_dir.y).normalized()

	# Выбор пресета
	var preset = run_preset if Input.is_action_pressed("run") and direction.length() > 0.1 else walk_preset

	# Плавное движение
	var target_vel = direction * preset.max_speed

	if direction != Vector3.ZERO:
		# Проекция на новое направление
		var forward_component = velocity.dot(direction.normalized())
		forward_component = max(0, forward_component)

		# Срезание боковой компоненты
		var perp = velocity - direction.normalized() * forward_component
		perp = perp.move_toward(Vector3.ZERO, 60.0 * delta)  # ← подкрути здесь

		# Ускорение в новом направлении
		velocity = direction * forward_component + direction * (preset.max_speed / preset.acceleration_time) * delta

		# Ограничение максимальной скорости
		if velocity.length() > preset.max_speed:
			velocity = velocity.normalized() * preset.max_speed

		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 12.0 * delta)
	else:
		var decel = preset.max_speed / preset.deceleration_time
		
		# Если только что был в беге — ускоряем торможение
		if last_running:
			decel *= run_deceleration_multiplier  # ← вот здесь магия
		
		velocity = velocity.move_toward(Vector3.ZERO, decel * delta)

	move_and_slide()

	# Условия
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
