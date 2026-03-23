extends Node

@onready var layer: CanvasLayer = $DragPreviewLayer
@onready var icon: TextureRect = $DragPreviewLayer/PreviewIcon
@onready var count_label: Label = $DragPreviewLayer/PreviewIcon/CountLabel

func _ready():
	print("DragPreview _ready() — слой:", layer)
	print("Icon:", icon)
	print("CountLabel:", count_label)
	
	if layer:
		layer.layer = 128  # высокий слой, поверх всего UI
	hide_preview()

func show_preview(stack: ItemStack):
	if not icon or not stack or not stack.item:
		hide_preview()
		return
	
	icon.texture = stack.item.icon
	icon.visible = true
	icon.modulate = Color(1,1,1,1)  # полностью видимый
	
	if count_label:
		count_label.text = str(stack.count) if stack.count > 1 else ""
		count_label.visible = stack.count > 1
	
	layer.visible = true  # ← обязательно показываем слой
	print("Preview показан: ", stack.item.display_name, " x", stack.count)

func hide_preview():
	if icon: icon.visible = false
	if count_label: count_label.visible = false
	if layer: layer.visible = false
	print("Preview скрыт")

func _process(_delta):
	if layer.visible and icon and icon.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		icon.position = mouse_pos + Vector2(25, 25)  # position, а не global_position
		if count_label:
			count_label.position = icon.size - Vector2(30, 30)
