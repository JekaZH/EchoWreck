extends Node
## Глобальная подсветка лута: outline предмета + столб/частицы (Alt+L / Alt+ЛКМ).

const ACTION_TOGGLE_OUTLINES := "toggle_dropped_item_outlines"

signal outlines_enabled_changed(enabled: bool)

var outlines_enabled: bool = true


func _ready() -> void:
	_ensure_input_action_registered()


func toggle_outlines() -> void:
	set_outlines_enabled(not outlines_enabled)


func set_outlines_enabled(enabled: bool) -> void:
	if outlines_enabled == enabled:
		return
	outlines_enabled = enabled
	outlines_enabled_changed.emit(outlines_enabled)
	_refresh_all_dropped_items()


func _ensure_input_action_registered() -> void:
	if InputMap.has_action(ACTION_TOGGLE_OUTLINES):
		return
	InputMap.add_action(ACTION_TOGGLE_OUTLINES, 0.2)
	var key_ev := InputEventKey.new()
	key_ev.physical_keycode = KEY_L
	key_ev.alt_pressed = true
	InputMap.action_add_event(ACTION_TOGGLE_OUTLINES, key_ev)
	var mouse_ev := InputEventMouseButton.new()
	mouse_ev.button_index = MOUSE_BUTTON_LEFT
	mouse_ev.alt_pressed = true
	InputMap.action_add_event(ACTION_TOGGLE_OUTLINES, mouse_ev)


func _refresh_all_dropped_items() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group("dropped_items"):
		if node is DroppedItem:
			(node as DroppedItem).refresh_loot_highlight()
