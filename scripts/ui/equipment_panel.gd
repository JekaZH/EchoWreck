extends Control

@export var screen_margin: Vector2 = Vector2(24, 24)

@onready var background: Control = $Background

func setup(equipment: PlayerEquipment):
	for child in find_children("*", "EquipmentSlot", true, false):
		child.setup(equipment)

func place_next_to(target: Control, side: String = "RIGHT") -> void:
	if not target or not is_instance_valid(target):
		return
	call_deferred("_place_next_to_deferred", target, side)

func _place_next_to_deferred(target: Control, side: String) -> void:
	if not is_instance_valid(target) or not is_instance_valid(background):
		return

	await get_tree().process_frame
	var size: Vector2 = background.get_combined_minimum_size()
	size.x = max(size.x, 1.0)
	size.y = max(size.y, 1.0)

	var vp: Vector2 = get_viewport_rect().size
	var margin := screen_margin
	margin.x = max(0.0, margin.x)
	margin.y = max(0.0, margin.y)
	var available_h: float = vp.y - margin.y * 2.0

	# Prefer no-scroll: we don't clamp height here.

	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 0.0
	background.anchor_bottom = 0.0
	background.offset_left = 0.0
	background.offset_top = 0.0
	background.offset_right = size.x
	background.offset_bottom = size.y

	custom_minimum_size = size
	self.size = size

	var desired_pos := position
	if side == "RIGHT":
		desired_pos = Vector2(target.position.x + target.size.x + margin.x, target.position.y)
	elif side == "LEFT":
		desired_pos = Vector2(target.position.x - size.x - margin.x, target.position.y)
	elif side == "TOP":
		desired_pos = Vector2(target.position.x, target.position.y - size.y - margin.y)
	elif side == "BOTTOM":
		desired_pos = Vector2(target.position.x, target.position.y + target.size.y + margin.y)

	# Keep equipment panel level with inventory window.
	desired_pos.y = target.position.y

	var max_x := vp.x - size.x - margin.x
	var max_y := vp.y - size.y - margin.y
	desired_pos.x = clampf(desired_pos.x, margin.x, max_x)
	desired_pos.y = clampf(desired_pos.y, margin.y, max_y)
	position = desired_pos
