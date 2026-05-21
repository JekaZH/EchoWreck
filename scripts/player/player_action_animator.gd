class_name PlayerActionAnimator
extends Node

## Одноразовые клипы: напрямую через AnimationPlayer (дерево выкл.), т.к. сигнал
## animation_finished у связанного AnimationTree обычно не приходит.

signal action_hit_frame
## Можно снова двигаться и жать удар/подбор (клип ещё доигрывается).
signal action_recovery
signal action_finished(kind: String)

const ANIM_HARVEST := "TreeChopping"
const ANIM_SWORD := "Sword_Attack"
const ANIM_PICKUP := "PickUp_Table"
const ANIM_DEATH := "Death01"

## Базовая скорость клипа (>1 — быстрее). Умножается на action_anim_speed_scale предмета.
const DEFAULT_SPEED := {
	ANIM_HARVEST: 1.75,
	ANIM_SWORD: 1.85,
	ANIM_PICKUP: 1.55,
	ANIM_DEATH: 1.0,
}

## Доля длительности клипа: раньше отпускаем ввод, раньше обрываем клип (меньше пауза между ударами).
const RECOVERY_AT := 0.58
const END_AT := 0.72

const STATE_IDLE := &"Idle"

var _player: Player
var _anim_tree: AnimationTree
var _anim_player: AnimationPlayer
var _busy: bool = false
var _current_kind: String = ""
var _current_anim: StringName = &""
var _hit_emitted: bool = false
var _action_generation: int = 0
var _saved_loop_mode: Dictionary = {}  # anim_name -> loop_mode


func setup(player: Player, anim_tree: AnimationTree, anim_player: AnimationPlayer) -> void:
	_player = player
	_anim_tree = anim_tree
	_anim_player = anim_player
	if _anim_player:
		_anim_player.animation_finished.connect(_on_animation_player_finished)


func is_busy() -> bool:
	return _busy


func play_item_action(item: ItemData) -> bool:
	if item == null:
		return false
	var anim_name := item.get_action_animation_name()
	if anim_name.is_empty():
		return false
	var speed_mul := item.action_anim_speed_scale if item.action_anim_speed_scale > 0.0 else 1.0
	var base := float(DEFAULT_SPEED.get(anim_name, 1.0))
	return _begin_action(anim_name, base * speed_mul, item.action_hit_time_ratio, "attack")


func try_play_pickup() -> bool:
	return _begin_action(ANIM_PICKUP, DEFAULT_SPEED[ANIM_PICKUP], 0.0, "pickup")


func play_death() -> void:
	_begin_action(ANIM_DEATH, DEFAULT_SPEED[ANIM_DEATH], 1.0, "death", false)


func _begin_action(
	anim_name: String,
	speed: float,
	hit_ratio: float,
	kind: String,
	restore_locomotion: bool = true
) -> bool:
	if _anim_player == null:
		return false
	if _busy:
		return false
	if not _anim_player.has_animation(anim_name):
		push_warning("PlayerActionAnimator: нет анимации '%s'" % anim_name)
		return false

	_busy = true
	_current_kind = kind
	_current_anim = StringName(anim_name)
	_hit_emitted = false
	_restore_locomotion_after = restore_locomotion

	_disable_anim_tree()
	_prepare_clip_no_loop(anim_name)

	speed = clampf(speed, 0.5, 3.0)
	_anim_player.speed_scale = speed
	_anim_player.stop()
	_anim_player.play(anim_name)

	var duration := _get_clip_duration(anim_name, speed)
	_schedule_timers(duration, kind, hit_ratio)

	return true


var _restore_locomotion_after: bool = true


func _disable_anim_tree() -> void:
	if _anim_tree == null:
		return
	_anim_tree.set("parameters/conditions/is_tree_chopping", false)
	_anim_tree.set("parameters/conditions/is_moving", false)
	_anim_tree.set("parameters/conditions/is_running", false)
	_anim_tree.set("parameters/conditions/is_not_moving", true)
	_anim_tree.set("parameters/conditions/is_not_running", true)
	_anim_tree.active = false


func _restore_anim_tree() -> void:
	if _anim_tree == null or not _restore_locomotion_after:
		return
	if _player != null and _player.is_dead():
		return
	_anim_tree.set("parameters/conditions/is_tree_chopping", false)
	var playback: AnimationNodeStateMachinePlayback = _anim_tree.get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	if playback != null:
		playback.travel(STATE_IDLE)
		playback.start(STATE_IDLE)
	_anim_tree.active = true


func _prepare_clip_no_loop(anim_name: String) -> void:
	var clip := _anim_player.get_animation(anim_name)
	if clip == null:
		return
	if not _saved_loop_mode.has(anim_name):
		_saved_loop_mode[anim_name] = clip.loop_mode
	clip.loop_mode = Animation.LOOP_NONE


func _restore_clip_loop(anim_name: String) -> void:
	if not _saved_loop_mode.has(anim_name):
		return
	var clip := _anim_player.get_animation(anim_name)
	if clip != null:
		clip.loop_mode = _saved_loop_mode[anim_name]


func _get_clip_duration(anim_name: String, speed: float) -> float:
	var clip := _anim_player.get_animation(anim_name)
	if clip == null:
		return 0.45
	return maxf(0.2, clip.length / speed)


func _schedule_timers(duration: float, kind: String, hit_ratio: float) -> void:
	_action_generation += 1
	var gen := _action_generation

	get_tree().create_timer(duration * RECOVERY_AT).timeout.connect(
		func() -> void: _on_recovery(gen), CONNECT_ONE_SHOT
	)
	get_tree().create_timer(duration * END_AT).timeout.connect(
		func() -> void: _on_duration_elapsed(gen), CONNECT_ONE_SHOT
	)

	if kind == "attack" and hit_ratio > 0.0:
		var hit_t := clampf(hit_ratio, 0.1, 0.75) * duration
		get_tree().create_timer(hit_t).timeout.connect(_emit_hit, CONNECT_ONE_SHOT)


func _on_recovery(gen: int) -> void:
	if gen != _action_generation:
		return
	_busy = false
	action_recovery.emit()


func _emit_hit() -> void:
	if _hit_emitted or _current_kind != "attack":
		return
	_hit_emitted = true
	action_hit_frame.emit()


func _on_animation_player_finished(anim_name: StringName) -> void:
	if _busy and anim_name == _current_anim:
		_finish_action()


func _on_duration_elapsed(gen: int) -> void:
	if gen == _action_generation:
		_cleanup_action_end()


func _finish_action() -> void:
	_cleanup_action_end()


func _cleanup_action_end() -> void:
	if _current_anim == &"" and not _busy:
		return

	var kind := _current_kind
	var anim_name := String(_current_anim)

	_busy = false
	_current_kind = ""
	_current_anim = &""

	if _anim_player:
		_anim_player.stop()
		_anim_player.speed_scale = 1.0
	if not anim_name.is_empty():
		_restore_clip_loop(anim_name)

	_restore_anim_tree()
	action_finished.emit(kind)
