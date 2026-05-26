class_name Chest
extends StaticBody3D

const ANIM_OPEN := &"Chest_Open"
const ANIM_CLOSE := &"Chest_Close"
const ANIM_CLOSED_POSE := &"Chest_Closed"
const ANIM_OPENED_POSE := &"Chest_Opened"

@export var interaction_label: String = "Открыть сундук"
@export var prompt_offset: Vector3 = Vector3(0.0, 1.1, 0.0)
@export var populate_from_loot_table: LootTable
@export var populate_on_ready: bool = true
@export var populate_only_if_empty: bool = true
@export var persist_id: String = ""

@onready var inventory: Inventory = $Inventory
@onready var interact_area: Area3D = $InteractArea
@onready var _anim: AnimationPlayer = $Chest_Wood/AnimationPlayer

var chest_ui: Control = null
var player_ui: Control = null
var _lid_busy: bool = false


func _ready() -> void:
	add_to_group("persist_chest")
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("Chest: нет дочернего Area3D 'InteractArea' у ", name)
	if populate_on_ready:
		_populate_admin()
	call_deferred("_play_closed_pose")


func is_open() -> bool:
	return chest_ui != null and is_instance_valid(chest_ui)


func get_prompt_world_position() -> Vector3:
	return global_position + prompt_offset


func get_interaction_text() -> String:
	return interaction_label


func interact(player: Node) -> void:
	if player == null:
		return
	toggle_chest(player)


func close_if_open() -> void:
	if is_open():
		close_windows()


func _play_closed_pose() -> void:
	if _anim == null:
		return
	if _lid_busy:
		return
	if _anim.has_animation(ANIM_CLOSED_POSE):
		_anim.play(ANIM_CLOSED_POSE)
	elif _anim.has_animation(ANIM_CLOSE):
		_anim.play(ANIM_CLOSE)
		_anim.seek(_anim.get_animation(ANIM_CLOSE).length, true)


func _play_open_lid() -> void:
	if _anim == null:
		return
	_lid_busy = true
	if _anim.has_animation(ANIM_OPEN):
		var length := _anim.get_animation(ANIM_OPEN).length
		_anim.play(ANIM_OPEN)
		var timer := get_tree().create_timer(length)
		timer.timeout.connect(_on_open_lid_finished, CONNECT_ONE_SHOT)
	else:
		_on_open_lid_finished()


func _play_close_lid() -> void:
	if _anim == null:
		return
	_lid_busy = true
	if _anim.has_animation(ANIM_CLOSE):
		var length := _anim.get_animation(ANIM_CLOSE).length
		_anim.play(ANIM_CLOSE)
		var timer := get_tree().create_timer(length)
		timer.timeout.connect(_on_close_lid_finished, CONNECT_ONE_SHOT)
	else:
		_on_close_lid_finished()


func _on_open_lid_finished() -> void:
	_lid_busy = false
	if _anim != null and _anim.has_animation(ANIM_OPENED_POSE):
		_anim.play(ANIM_OPENED_POSE)


func _on_close_lid_finished() -> void:
	_lid_busy = false
	_play_closed_pose()


func _is_inventory_empty() -> bool:
	if inventory == null:
		return true
	for i in inventory.slots_count:
		if inventory.get_slot(i) != null:
			return false
	return true


func _populate_admin() -> void:
	if inventory == null:
		return
	if populate_only_if_empty and not _is_inventory_empty():
		return
	if populate_from_loot_table:
		_populate_from_loot(populate_from_loot_table)


func _populate_from_loot(table: LootTable) -> void:
	if table == null:
		return
	for entry in table.entries:
		if entry == null or entry.item == null:
			continue
		if randf() >= entry.chance:
			continue
		var amount: int = randi_range(entry.min_count, entry.max_count)
		if amount <= 0:
			continue
		inventory.add_item(entry.item, amount)


func _on_body_entered(body: Node3D) -> void:
	if body != null and body.is_in_group("player"):
		if body.has_method("register_interactable"):
			body.register_interactable(self)


func _on_body_exited(body: Node3D) -> void:
	if body != null and body.is_in_group("player"):
		if body.has_method("unregister_interactable"):
			body.unregister_interactable(self)
		close_windows()


func toggle_chest(player: Node) -> void:
	if is_open():
		close_windows()
	else:
		open_both_windows(player)


func open_both_windows(player: Node) -> void:
	close_windows()
	if player == null or not player.has_method("close_all_ui"):
		return
	player.close_all_ui()
	_play_open_lid()
	var ui_scene := preload("res://scenes/inventory/universal_inventory.tscn")
	chest_ui = ui_scene.instantiate()
	chest_ui.inventory = inventory
	chest_ui.title = "Сундук"
	chest_ui.columns = 4
	chest_ui.placement = "LEFT"
	chest_ui.show_close_button = false
	chest_ui.add_to_group("inventory_ui")
	get_tree().current_scene.add_child(chest_ui)
	chest_ui.tree_exiting.connect(_on_chest_ui_tree_exiting)
	player_ui = ui_scene.instantiate()
	player_ui.inventory = player.get_node("Inventory")
	player_ui.title = "Инвентарь"
	player_ui.columns = 6
	player_ui.placement = "RIGHT"
	player_ui.show_close_button = false
	player_ui.add_to_group("inventory_ui")
	get_tree().current_scene.add_child(player_ui)
	player_ui.tree_exiting.connect(_on_player_ui_tree_exiting)


func close_windows() -> void:
	if not is_open():
		return
	if chest_ui != null and is_instance_valid(chest_ui):
		chest_ui.queue_free()
	chest_ui = null
	if player_ui != null and is_instance_valid(player_ui):
		player_ui.queue_free()
	player_ui = null
	_play_close_lid()


func _on_chest_ui_tree_exiting() -> void:
	chest_ui = null


func _on_player_ui_tree_exiting() -> void:
	player_ui = null
