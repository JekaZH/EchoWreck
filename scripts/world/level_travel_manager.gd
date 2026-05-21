extends Node

## Autoload: переходы между сценами уровней и появление у `LevelSpawnPoint`.

const CONFIRM_SCENE := preload("res://scenes/ui/level_travel_confirm.tscn")
const DEFAULT_LEVEL := "res://scenes/main.tscn"

var _pending_arrival_portal_id: String = ""
var _active_zone: LevelTransitionZone = null
var _confirm_ui: LevelTravelConfirmController = null
## Снимок игрока при переходе между уровнями (без записи на диск).
var _travel_player_snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_ui = CONFIRM_SCENE.instantiate() as LevelTravelConfirmController
	_confirm_ui.hide()
	get_tree().root.call_deferred("add_child", _confirm_ui)
	_confirm_ui.confirmed.connect(_on_confirm_yes)
	_confirm_ui.cancelled.connect(_on_confirm_no)


func clear_travel_state() -> void:
	_pending_arrival_portal_id = ""
	_travel_player_snapshot.clear()
	_active_zone = null
	# Кэш миров уровней не сбрасываем — только при новой игре / меню.
	if _confirm_ui:
		_confirm_ui.hide_dialog()


func offer_travel(zone: LevelTransitionZone) -> void:
	if zone == null:
		return
	_active_zone = zone
	if _confirm_ui:
		_confirm_ui.show_offer(zone.get_prompt_text())


func cancel_offer(zone: LevelTransitionZone) -> void:
	if _active_zone != zone:
		return
	_active_zone = null
	if _confirm_ui:
		_confirm_ui.hide_dialog()


func commit_travel(zone: LevelTransitionZone = null) -> void:
	var z: LevelTransitionZone = zone if zone != null else _active_zone
	if z == null:
		return
	var path := z.get_resolved_level_path()
	if path.is_empty():
		push_warning("LevelTravelManager: пустой путь целевого уровня у зоны '%s'" % z.name)
		return
	if not ResourceLoader.exists(path):
		push_error("LevelTravelManager: сцена не найдена: %s" % path)
		return

	_pending_arrival_portal_id = z.get_arrival_portal_id()
	_active_zone = null
	if _confirm_ui:
		_confirm_ui.hide_dialog()

	var main_scene := get_tree().current_scene as Node3D
	if main_scene:
		LevelWorldCache.capture_level(main_scene)

	_capture_player_snapshot_before_travel()

	get_tree().paused = false
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("LevelTravelManager: не удалось загрузить %s" % path)
		_pending_arrival_portal_id = ""
		return
	get_tree().change_scene_to_packed(packed)


func _on_confirm_yes() -> void:
	commit_travel()


func _on_confirm_no() -> void:
	_active_zone = null


## После загрузки сцены: поставить игрока у маркера (переход или сейв с portal в extension — позже).
func apply_travel_player_snapshot(main_root: Node3D) -> void:
	if _travel_player_snapshot.is_empty():
		return
	var player := main_root.get_node_or_null("Player") as Player
	if player == null:
		_travel_player_snapshot.clear()
		return
	SaveGameState.apply_player_payload(player, _travel_player_snapshot)
	_travel_player_snapshot.clear()


func _capture_player_snapshot_before_travel() -> void:
	_travel_player_snapshot.clear()
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player") as Player
	if player == null:
		return
	_travel_player_snapshot = SaveGameState.build_player_payload(player)


func apply_arrival_to_player(main_root: Node3D) -> bool:
	if _pending_arrival_portal_id.is_empty():
		return false
	var player := main_root.get_node_or_null("Player") as Node3D
	if player == null:
		_pending_arrival_portal_id = ""
		return false
	var portal := _pending_arrival_portal_id
	_pending_arrival_portal_id = ""
	var spawn := _find_spawn(main_root, portal)
	if spawn == null:
		push_warning(
			"LevelTravelManager: на уровне нет LevelSpawnPoint с portal_id='%s'" % portal
		)
		return false
	player.global_transform = spawn.get_spawn_transform()
	return true


static func _find_spawn(main_root: Node, portal_id: String) -> LevelSpawnPoint:
	var fallback: LevelSpawnPoint = null
	for n in main_root.get_tree().get_nodes_in_group("level_spawn"):
		if not (n is LevelSpawnPoint):
			continue
		if not main_root.is_ancestor_of(n):
			continue
		var sp := n as LevelSpawnPoint
		if sp.portal_id == portal_id:
			return sp
		if sp.portal_id == "default" and fallback == null:
			fallback = sp
	return fallback


func resolve_level_scene_path(path: String) -> String:
	if path.is_empty():
		return DEFAULT_LEVEL
	if ResourceLoader.exists(path):
		return path
	push_warning("LevelTravelManager: сцена не найдена %s, fallback main" % path)
	return DEFAULT_LEVEL
