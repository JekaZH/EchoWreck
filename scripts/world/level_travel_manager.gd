extends Node

## Autoload: переходы между сценами уровней, экран загрузки, появление у `LevelSpawnPoint`.

const CONFIRM_SCENE := preload("res://scenes/ui/level_travel_confirm.tscn")
const LOADING_SCENE := preload("res://scenes/ui/level_loading_screen.tscn")
const DEFAULT_LEVEL := "res://scenes/main.tscn"

var _pending_arrival_portal_id: String = ""
var _active_zone: LevelTransitionZone = null
var _confirm_ui: LevelTravelConfirmController = null
var _loading_ui: LevelLoadingScreen = null
var _awaiting_bootstrap: bool = false
## Снимок игрока при переходе между уровнями (без записи на диск).
var _travel_player_snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_ui = CONFIRM_SCENE.instantiate() as LevelTravelConfirmController
	_confirm_ui.hide()
	get_tree().root.call_deferred("add_child", _confirm_ui)
	_confirm_ui.confirmed.connect(_on_confirm_yes)
	_confirm_ui.cancelled.connect(_on_confirm_no)
	call_deferred("_attach_loading_ui")


func clear_travel_state() -> void:
	_pending_arrival_portal_id = ""
	_travel_player_snapshot.clear()
	_active_zone = null
	_awaiting_bootstrap = false
	if _confirm_ui:
		_confirm_ui.hide_dialog()
	if _loading_ui:
		_loading_ui.hide_loading()


func is_level_transition_active() -> bool:
	return _awaiting_bootstrap


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
	_run_commit_travel(zone)


func _run_commit_travel(zone: LevelTransitionZone = null) -> void:
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
	await transition_to_level(path)


func transition_to_level(path: String, status_message: String = "Загрузка уровня...") -> void:
	var resolved := resolve_level_scene_path(path)
	if not await _ensure_loading_ui_ready():
		push_error("LevelTravelManager: экран загрузки недоступен")
		return
	_awaiting_bootstrap = true
	_loading_ui.show_loading(status_message)
	_loading_ui.set_progress(0.05)

	var tree := get_tree()
	if tree == null:
		_awaiting_bootstrap = false
		_loading_ui.hide_loading()
		return

	tree.paused = false
	await tree.process_frame

	_loading_ui.set_progress(0.12)
	var err := ResourceLoader.load_threaded_request(resolved)
	if err != OK:
		push_error("LevelTravelManager: load_threaded_request failed %d for %s" % [err, resolved])
		_abort_transition()
		return

	while true:
		var progress: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
			resolved, progress
		)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				var ratio := 0.12
				if progress.size() > 0:
					ratio = 0.12 + float(progress[0]) * 0.55
				_loading_ui.set_progress(ratio)
				await tree.process_frame
			ResourceLoader.THREAD_LOAD_LOADED:
				break
			_:
				push_error("LevelTravelManager: не удалось загрузить %s (status %d)" % [resolved, status])
				_abort_transition()
				return

	var packed := ResourceLoader.load_threaded_get(resolved) as PackedScene
	if packed == null:
		push_error("LevelTravelManager: packed scene null %s" % resolved)
		_abort_transition()
		return

	_loading_ui.set_progress(0.72)
	await tree.process_frame
	tree.change_scene_to_packed(packed)

	while _awaiting_bootstrap:
		await tree.process_frame


func finish_level_transition() -> void:
	if not _awaiting_bootstrap:
		return
	if _loading_ui == null or not is_instance_valid(_loading_ui):
		_awaiting_bootstrap = false
		return
	_loading_ui.set_progress(0.95)
	var tree := get_tree()
	if tree:
		await tree.process_frame
		await tree.process_frame
	_loading_ui.set_progress(1.0)
	await get_tree().create_timer(0.04).timeout
	if _loading_ui:
		_loading_ui.hide_loading()
	_awaiting_bootstrap = false


func _abort_transition() -> void:
	_awaiting_bootstrap = false
	if _loading_ui:
		_loading_ui.hide_loading()


func _on_confirm_yes() -> void:
	_run_commit_travel()


func _on_confirm_no() -> void:
	_active_zone = null


func _attach_loading_ui() -> void:
	await _ensure_loading_ui_ready()


func _ensure_loading_ui_ready() -> bool:
	if _loading_ui != null and is_instance_valid(_loading_ui):
		if _loading_ui.is_inside_tree():
			if not _loading_ui.is_node_ready():
				await _loading_ui.ready
			return true
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	if _loading_ui == null or not is_instance_valid(_loading_ui):
		_loading_ui = LOADING_SCENE.instantiate() as LevelLoadingScreen
	if _loading_ui == null:
		return false
	if not _loading_ui.is_inside_tree():
		tree.root.call_deferred("add_child", _loading_ui)
		await tree.process_frame
		if not _loading_ui.is_inside_tree():
			await tree.process_frame
	if not _loading_ui.is_node_ready():
		await _loading_ui.ready
	_loading_ui.hide_loading()
	return true


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
	var normalized := LevelWorldCache.normalize_level_key(path)
	if ResourceLoader.exists(normalized):
		return normalized
	push_warning("LevelTravelManager: сцена не найдена %s, fallback main" % path)
	return DEFAULT_LEVEL
