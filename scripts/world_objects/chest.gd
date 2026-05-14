class_name Chest
extends StaticBody3D

@onready var inventory: Inventory = $Inventory
@onready var interact_area: Area3D = $InteractArea

var player_in_range: bool = false
var chest_ui: Control = null
var player_ui: Control = null

@export var populate_from_loot_table: LootTable
@export var populate_on_ready: bool = true
@export var populate_only_if_empty: bool = true

func _ready():
	add_to_group("persist_chest")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	if populate_on_ready:
		_populate_admin()

func _is_inventory_empty() -> bool:
	if not inventory:
		return true
	for i in inventory.slots_count:
		if inventory.get_slot(i) != null:
			return false
	return true

func _populate_admin() -> void:
	if not inventory:
		return
	if populate_only_if_empty and not _is_inventory_empty():
		return
	if populate_from_loot_table:
		_populate_from_loot(populate_from_loot_table)
		return

func _populate_from_loot(table: LootTable) -> void:
	if not table:
		return
	for entry in table.entries:
		if not entry or not entry.item:
			continue
		if randf() >= entry.chance:
			continue
		var count: int = randi_range(entry.min_count, entry.max_count)
		if count <= 0:
			continue
		inventory.add_item(entry.item, count)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		close_windows()

func _input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		toggle_chest()
	
	if event.is_action_pressed("ui_cancel"):
		close_windows()

func toggle_chest():
	if chest_ui and is_instance_valid(chest_ui):
		close_windows()
	else:
		open_both_windows()

func open_both_windows():
	close_windows()
	
	# Закрываем окно игрока, если оно открыто
	#var player = get_tree().get_first_node_in_group("player")
	#if player and player.current_inventory_ui and is_instance_valid(player.current_inventory_ui):
		#player.current_inventory_ui.queue_free()
		#player.current_inventory_ui = null
		#print("Закрыто окно игрока при открытии сундука")
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.close_all_ui()
		print("Закрыли весь UI игрока перед открытием сундука")
	
	var ui_scene = preload("res://scenes/inventory/universal_inventory.tscn")
	
	# Сундук слева
	chest_ui = ui_scene.instantiate()
	chest_ui.inventory = inventory
	chest_ui.title = "Сундук"
	chest_ui.columns = 4
	chest_ui.placement = "LEFT"
	chest_ui.show_close_button = false
	chest_ui.add_to_group("inventory_ui")  # ← группа
	get_tree().current_scene.add_child(chest_ui)
	
	# Инвентарь игрока справа
	player_ui = ui_scene.instantiate()
	player_ui.inventory = player.get_node("Inventory")
	player_ui.title = "Инвентарь"
	player_ui.columns = 6
	player_ui.placement = "RIGHT"
	player_ui.show_close_button = false
	player_ui.add_to_group("inventory_ui")
	get_tree().current_scene.add_child(player_ui)
	
	print("Открыты два окна бок о бок")

func close_windows():
	if chest_ui and is_instance_valid(chest_ui):
		chest_ui.queue_free()
		chest_ui = null
	if player_ui and is_instance_valid(player_ui):
		player_ui.queue_free()
		player_ui = null
