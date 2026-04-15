class_name InventoryUI
extends Control

@export var inventory: Inventory
@export var title: String = "Инвентарь"
@export var columns: int = 6
@export var slot_size: Vector2 = Vector2(64, 64)
@export var read_only: bool = false  # нельзя класть/брать, только смотреть
@export var take_only: bool = false  # можно только забирать (выход станции)
@export var show_close_button: bool = false
@export_enum("CENTER", "LEFT", "RIGHT", "CUSTOM") var placement: String = "CENTER"
@export var screen_margin: Vector2 = Vector2(24, 24)

@onready var background: Control = $Background
@onready var title_label: Label = $Background/Margin/VBox/Header/TitleLabel
@onready var slots_grid: GridContainer = $Background/Margin/VBox/SlotsGrid
@onready var close_button: Button = $Background/Margin/VBox/Header/CloseButton

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
	
	# Close button visibility/behavior
	if close_button:
		close_button.visible = show_close_button
		if show_close_button:
			close_button.pressed.connect(_on_close_pressed)
	
	# Создаём слоты
	for i in inventory.slots_count:
		var slot_scene = preload("res://scenes/inventory/inventory_slot.tscn")
		var slot = slot_scene.instantiate()
		slots_grid.add_child(slot)
		
		slot.setup(inventory, i)
		slot.take_only = take_only
		
		# Если read_only — отключаем взаимодействие
		if read_only:
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.modulate = Color(0.8, 0.8, 0.8, 1.0)  # слегка затемняем для вида
	
	# (CloseButton подключаем выше, только если он показывается)
	
	
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

	call_deferred("_fit_background_to_grid")


func _on_close_pressed() -> void:
	# If this is the player's inventory window, close the whole UI stack (inventory + equipment + stats).
	if title == "Инвентарь":
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("close_all_ui"):
			player.close_all_ui()
			return
	queue_free()

func _fit_background_to_grid() -> void:
	if not is_instance_valid(background) or not is_instance_valid(title_label) or not is_instance_valid(slots_grid):
		return
	
	var total_slots: int = inventory.slots_count
	var cols: int = max(1, columns)
	var rows: int = int(ceili(float(total_slots) / float(cols)))
	
	# GridContainer spacing
	var hsep: int = slots_grid.get_theme_constant("h_separation")
	var vsep: int = slots_grid.get_theme_constant("v_separation")
	
	var cell_w: float = slot_size.x
	var cell_h: float = slot_size.y
	
	var grid_w: float = cols * cell_w + max(0, cols - 1) * float(hsep)
	var grid_h: float = rows * cell_h + max(0, rows - 1) * float(vsep)
	
	# Let containers do the internal layout; here we only center the panel around its minimum size.
	slots_grid.custom_minimum_size = Vector2(grid_w, grid_h)
	
	await get_tree().process_frame
	var size: Vector2 = background.get_combined_minimum_size()
	size.x = max(size.x, 1.0)
	size.y = max(size.y, 1.0)
	
	# Background becomes a fixed-size panel inside this Control.
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 0.0
	background.anchor_bottom = 0.0
	background.offset_left = 0.0
	background.offset_top = 0.0
	background.offset_right = size.x
	background.offset_bottom = size.y
	
	self.custom_minimum_size = size
	self.size = size
	
	var vp: Vector2 = get_viewport_rect().size
	var margin := screen_margin
	margin.x = max(0.0, margin.x)
	margin.y = max(0.0, margin.y)
	
	var desired_pos := position
	match placement:
		"CENTER":
			desired_pos = (vp - size) * 0.5
		"LEFT":
			desired_pos = Vector2(margin.x, margin.y)
		"RIGHT":
			desired_pos = Vector2(vp.x - size.x - margin.x, margin.y)
		"CUSTOM":
			desired_pos = position
	
	# Clamp to viewport so it never goes off-screen.
	var max_x := vp.x - size.x - margin.x
	var max_y := vp.y - size.y - margin.y
	desired_pos.x = clampf(desired_pos.x, margin.x, max_x)
	desired_pos.y = clampf(desired_pos.y, margin.y, max_y)
	position = desired_pos

#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("ui_cancel"):
		#queue_free()
