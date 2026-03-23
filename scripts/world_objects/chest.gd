class_name Chest
extends StaticBody3D

@onready var inventory: Inventory = $Inventory
@onready var interact_area: Area3D = $InteractArea

var player_in_range: bool = false
var chest_ui: Control = null
var player_ui: Control = null



func _ready():
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

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

func toggle_chest():
	if chest_ui and is_instance_valid(chest_ui):
		close_windows()
	else:
		open_both_windows()

func open_both_windows():
	close_windows()
	
	var ui_scene = preload("res://scenes/inventory/universal_inventory.tscn")
	
	var ui_layer = get_tree().get_first_node_in_group("ui_layer")
	
	# Сундук — слева
	chest_ui = ui_scene.instantiate()
	chest_ui.inventory = inventory
	chest_ui.title = "Сундук"
	chest_ui.columns = 4
	chest_ui.position = Vector2(60, 60)
	ui_layer.add_child(chest_ui)
	
	# Инвентарь игрока — справа
	var player = get_tree().get_first_node_in_group("player")
	player_ui = ui_scene.instantiate()
	player_ui.inventory = player.get_node("Inventory")
	player_ui.title = "Инвентарь"
	player_ui.columns = 6
	player_ui.position = Vector2(680, 60)   # подкрути под своё разрешение экрана
	ui_layer.add_child(player_ui)
	
	print("Открыты два окна бок о бок")

func close_windows():
	if chest_ui and is_instance_valid(chest_ui):
		chest_ui.queue_free()
		chest_ui = null
	if player_ui and is_instance_valid(player_ui):
		player_ui.queue_free()
		player_ui = null
