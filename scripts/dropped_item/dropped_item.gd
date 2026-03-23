# dropped_item.gd
class_name DroppedItem
extends Node3D

@export var item_data: ItemData
@export var count: int = 1

@onready var pickup_area: Area3D = $PickupArea
@onready var label: Label3D = $Label3D  # добавим позже

func _ready() -> void:
	if label:
		label.text = "E to collect"
		label.visible = false

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.nearby_dropped_items.append(self)
		print("Предмет добавлен в зону игрока: ", item_data.display_name)
		if label:
			label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.nearby_dropped_items.erase(self)
		print("Предмет удалён из зоны игрока")
		if label:
			label.visible = false

func pickup() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("Inventory"):
		var inv = player.get_node("Inventory") as Inventory
		var success = inv.add_item(item_data, count)
		
		if success:
			print("Подобрано и добавлено в инвентарь: ", item_data.display_name, " x", count)
			queue_free()  # удаляем предмет с земли
		else:
			print("Инвентарь полон!")
	else:
		print("Игрок или Inventory не найден!")
