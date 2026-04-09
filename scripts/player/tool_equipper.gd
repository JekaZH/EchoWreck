class_name ToolEquipper
extends Node

@export var right_hand_bone_name: String = "RightHand"   # ← измени на имя твоей кости правой руки

var tool_pivot: Node3D = null
var grip_node: Node3D = null   # Новый узел для точного позиционирования
var current_tool: Node3D = null
var skeleton: Skeleton3D = null

func _ready():
	# Ищем скелет
	skeleton = get_parent().get_node_or_null("Armature/GeneralSkeleton")
	if not skeleton:
		skeleton = get_parent().get_node_or_null("GeneralSkeleton")  # попробуй этот вариант тоже
	
	if skeleton:
		setup_hand_attachment()
	else:
		push_error("ToolEquipper: Skeleton3D не найден!")

func setup_hand_attachment():
	# Создаём BoneAttachment3D программно
	var bone_attachment = BoneAttachment3D.new()
	bone_attachment.bone_name = right_hand_bone_name
	skeleton.add_child(bone_attachment)
	
	# Создаём pivot внутри BoneAttachment
	tool_pivot = Node3D.new()
	tool_pivot.name = "ToolPivot"
	bone_attachment.add_child(tool_pivot)
	
	# Добавляем Grip-узел для точного позиционирования кисти
	grip_node = Node3D.new()
	grip_node.name = "Grip"
	tool_pivot.add_child(grip_node)
	
	print("ToolEquipper: BoneAttachment и Grip созданы для кости", right_hand_bone_name)


func equip_tool(item: ItemData):
	if not grip_node:
		return

	# Убираем предыдущий инструмент
	if current_tool:
		current_tool.queue_free()
		current_tool = null

	if not item or not item.is_equippable or not item.equipped_scene:
		return

	current_tool = item.equipped_scene.instantiate()
	grip_node.add_child(current_tool)

	# Применяем смещение и поворот из ItemData
	current_tool.position = item.hand_offset
	current_tool.rotation_degrees = item.hand_rotation
	
	current_tool.set_meta("item_data", item)

	print("Экипирован инструмент:", item.display_name)

func clear_tool():
	if current_tool:
		current_tool.queue_free()
		current_tool = null
