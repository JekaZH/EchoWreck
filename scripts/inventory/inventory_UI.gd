class_name InventoryUI
extends Control

@export var inventory: Inventory
@export var title: String = "Инвентарь"
@export var columns: int = 6
@export var slot_size: Vector2 = Vector2(64, 64)
@export var read_only: bool = false  # нельзя класть/брать, только смотреть

@onready var title_label: Label = $Background/TitleLabel
@onready var slots_grid: GridContainer = $Background/SlotsGrid

func _ready() -> void:
	add_to_group("inventory_ui")
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not inventory:
		push_error("Inventory не установлен в UniversalInventoryUI!")
		queue_free()
		return
	
	title_label.text = title
	slots_grid.columns = columns
	
	# Создаём слоты
	for i in inventory.slots_count:
		var slot_scene = preload("res://scenes/inventory/inventory_slot.tscn")
		var slot = slot_scene.instantiate()
		slots_grid.add_child(slot)
		
		slot.setup(inventory, i)
		
		# Если read_only — отключаем взаимодействие
		if read_only:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.modulate = Color(0.8, 0.8, 0.8, 1.0)  # слегка затемняем для вида
	
	# Закрытие по кнопке
	if has_node("CloseButton"):
		$CloseButton.pressed.connect(queue_free)
	
	
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	for slot in slots_grid.get_children():
		if slot is InventorySlot:
			slot.mouse_filter = Control.MOUSE_FILTER_STOP   # важно!
			
			mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Чтобы preview работал поверх всех окон
	if Engine.is_editor_hint() == false:
		z_index = 10
	
	inventory.changed.emit()
	# Можно закрывать по Esc
	# (добавь в Input Map действие "ui_cancel" = Esc, если нужно)

#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("ui_cancel"):
		#queue_free()
