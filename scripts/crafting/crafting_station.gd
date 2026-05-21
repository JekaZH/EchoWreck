class_name CraftingStation
extends Node3D

signal craft_state_changed()
signal craft_progress_changed(progress_0_1: float)
signal craft_completed(recipe: CraftRecipe)
signal craft_failed(recipe: CraftRecipe, reason: String)

@export var station_type: CraftingStationType

# Опционально: можно поставить outline/иконку/текст подсказки позже (Этап 8).
@export var interaction_label: String = "Крафт"
@export var prompt_offset: Vector3 = Vector3(0.0, 1.6, 0.0)
## Стабильный id для сохранений (уникален внутри сцены уровня). Пусто = путь узла.
@export var persist_id: String = ""

@onready var interact_area: Area3D = get_node_or_null("InteractArea")
@onready var fuel_inventory: Inventory = get_node_or_null("FuelInventory")
@onready var output_inventory: Inventory = get_node_or_null("OutputInventory")
@onready var sfx_player: AudioStreamPlayer3D = get_node_or_null("SFX")

var _active_recipe: CraftRecipe = null
var _active_sources: Array[Inventory] = []
var _output_inventory: Inventory = null
var _time_total: float = 0.0
var _time_left: float = 0.0
var _is_crafting: bool = false
var _fuel_buffer_seconds: float = 0.0
var _queue: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("persist_crafting_station")
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("CraftingStation: нет дочернего Area3D 'InteractArea' у " + name)
	
	if fuel_inventory == null and station_type != null and station_type.supports_fuel:
		push_warning("CraftingStation: supports_fuel=true, но нет FuelInventory у " + name)
	if output_inventory == null:
		push_warning("CraftingStation: нет OutputInventory у " + name + " (нужен для фонового крафта)")


func get_output_inventory() -> Inventory:
	return output_inventory


func _sim_add_to_sim(sim: Array, p_item: ItemData, p_amount: int) -> bool:
	var remaining := p_amount
	# stack into existing
	for i in sim.size():
		if remaining <= 0:
			break
		var cell = sim[i]
		if cell == null:
			continue
		if cell["item"] != p_item:
			continue
		var space := p_item.max_stack - int(cell["count"])
		if space <= 0:
			continue
		var added := mini(space, remaining)
		cell["count"] = int(cell["count"]) + added
		remaining -= added
	
	# new stacks
	for i in sim.size():
		if remaining <= 0:
			break
		if sim[i] != null:
			continue
		var stack_size := mini(p_item.max_stack, remaining)
		sim[i] = {"item": p_item, "count": stack_size}
		remaining -= stack_size
	
	return remaining <= 0


func _simulate_output_can_fit_after_queue(item: ItemData, amount: int) -> bool:
	if output_inventory == null or item == null or amount <= 0:
		return false
	# Simulate current output + all queued results + this result.
	var sim: Array = []
	sim.resize(output_inventory.slots_count)
	for i in output_inventory.slots_count:
		var st := output_inventory.get_slot(i)
		if st == null or st.item == null or st.count <= 0:
			sim[i] = null
		else:
			sim[i] = {"item": st.item, "count": st.count}
	
	# Apply queued outputs
	for job in _queue:
		if not job.has("recipe"):
			continue
		var r: CraftRecipe = job["recipe"]
		if r == null or r.result == null or r.result.item == null:
			continue
		if not _sim_add_to_sim(sim, r.result.item, r.result.amount):
			return false
	# Apply current active output too (if any)
	if _active_recipe != null and _active_recipe.result != null and _active_recipe.result.item != null:
		if not _sim_add_to_sim(sim, _active_recipe.result.item, _active_recipe.result.amount):
			return false
	
	return _sim_add_to_sim(sim, item, amount)

func _on_body_entered(body: Node) -> void:
	if body and body.is_in_group("player"):
		if body.has_method("register_interactable"):
			body.register_interactable(self)

func _on_body_exited(body: Node) -> void:
	if body and body.is_in_group("player"):
		if body.has_method("unregister_interactable"):
			body.unregister_interactable(self)

func get_prompt_world_position() -> Vector3:
	return global_position + prompt_offset

func get_interaction_text() -> String:
	var station_name := station_type.display_name if station_type != null else "Станция"
	return "%s (%s)" % [interaction_label, station_name]

func interact(player: Node) -> void:
	if player == null:
		return
	if station_type == null:
		push_warning("CraftingStation: station_type не задан для " + name)
		return
	
	# Открываем UI крафта с фильтром по станции.
	if player.has_method("open_crafting_ui"):
		player.open_crafting_ui(station_type, self)
	else:
		push_warning("CraftingStation: Player не имеет метода open_crafting_ui()")


func is_busy() -> bool:
	return _is_crafting


func get_active_recipe() -> CraftRecipe:
	return _active_recipe


func get_fuel_seconds_available() -> float:
	return _fuel_buffer_seconds


func get_fuel_buffer_seconds() -> float:
	return _fuel_buffer_seconds


func export_persist_state() -> Dictionary:
	var jobs: Array = []
	if _is_crafting and _active_recipe != null:
		jobs.append(_persist_job_dict(_active_recipe, _time_left, _time_total))
	for job in _queue:
		if job is Dictionary:
			var recipe: CraftRecipe = job.get("recipe")
			if recipe != null:
				jobs.append(_persist_job_dict(recipe, float(job.get("time_left", 0.0)), float(job.get("time_total", 0.0))))
	return {
		"craft_jobs": jobs,
		"fuel_buffer_seconds": _fuel_buffer_seconds,
	}


func _persist_job_dict(recipe: CraftRecipe, time_left: float, time_total: float) -> Dictionary:
	var path := ""
	if recipe != null and not recipe.resource_path.is_empty():
		path = recipe.resource_path
	elif recipe != null and not String(recipe.id).is_empty():
		path = "id:%s" % String(recipe.id)
	return {
		"recipe_path": path,
		"time_left": time_left,
		"time_total": time_total,
	}


func import_persist_state(data: Variant) -> void:
	_cancel_active("persist_reset")
	_queue.clear()
	_fuel_buffer_seconds = 0.0
	if not (data is Dictionary):
		return
	var dict := data as Dictionary
	_fuel_buffer_seconds = float(dict.get("fuel_buffer_seconds", 0.0))
	var jobs_v: Variant = dict.get("craft_jobs", [])
	if not (jobs_v is Array):
		return
	for entry in jobs_v as Array:
		if not (entry is Dictionary):
			continue
		var e := entry as Dictionary
		var recipe := _resolve_recipe_for_persist(str(e.get("recipe_path", "")))
		if recipe == null:
			continue
		_queue.append({
			"recipe": recipe,
			"time_total": float(e.get("time_total", recipe.craft_time_seconds)),
			"time_left": float(e.get("time_left", 0.0)),
		})
	if not _is_crafting and not _queue.is_empty():
		_start_next_job()


func _resolve_recipe_for_persist(path_or_id: String) -> CraftRecipe:
	if path_or_id.is_empty():
		return null
	if path_or_id.begins_with("id:"):
		var rid := path_or_id.substr(3)
		var dir := DirAccess.open("res://resources/crafting/recipes/")
		if dir:
			for f in dir.get_files():
				if not f.ends_with(".tres"):
					continue
				var r := load("res://resources/crafting/recipes/%s" % f) as CraftRecipe
				if r and String(r.id) == rid:
					return r
		return null
	if ResourceLoader.exists(path_or_id):
		return load(path_or_id) as CraftRecipe
	return null


func restore_persisted_fuel_buffer_seconds(seconds: float) -> void:
	_fuel_buffer_seconds = maxf(0.0, seconds)


func _count_fuel_seconds_in_sources(sources: Array[Inventory]) -> float:
	var total := 0.0
	for inv in sources:
		if inv == null:
			continue
		for i in inv.slots_count:
			var st := inv.get_slot(i)
			if st == null or st.item == null or st.count <= 0:
				continue
			if st.item.burn_seconds <= 0.0:
				continue
			total += float(st.count) * st.item.burn_seconds
	return total


func get_total_fuel_seconds_available(sources: Array[Inventory]) -> float:
	return _fuel_buffer_seconds + _count_fuel_seconds_in_sources(sources)


func _build_fuel_types_in_sources(sources: Array[Inventory]) -> Array[ItemData]:
	var fuel_types: Array[ItemData] = []
	for inv in sources:
		if inv == null:
			continue
		for i in inv.slots_count:
			var st := inv.get_slot(i)
			if st == null or st.item == null or st.count <= 0:
				continue
			if st.item.burn_seconds <= 0.0:
				continue
			if not fuel_types.has(st.item):
				fuel_types.append(st.item)
	# Default: prefer cheaper/smaller fuel first (so coal isn't spent for a 10s craft).
	fuel_types.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.burn_seconds < b.burn_seconds
	)
	return fuel_types


func preview_fuel_take_for_specific_item(seconds_needed: float, sources: Array[Inventory], fuel_item: ItemData) -> Dictionary:
	var plan: Dictionary = {}
	if seconds_needed <= 0.0 or fuel_item == null:
		return plan
	if fuel_item.burn_seconds <= 0.0:
		return plan
	
	if _fuel_buffer_seconds >= seconds_needed:
		return plan
	
	var remaining := seconds_needed - _fuel_buffer_seconds
	var have := Crafting.count_item_multi(sources, fuel_item)
	if have <= 0:
		return plan
	var take := int(ceili(remaining / fuel_item.burn_seconds))
	take = mini(take, have)
	if take > 0:
		plan[fuel_item] = take
	return plan


func preview_auto_fuel_take(seconds_needed: float, sources: Array[Inventory]) -> Dictionary:
	# Plan: what items to take from player sources to ensure enough fuel,
	# without wasting: we add items to buffer and consume exactly seconds_needed.
	var plan: Dictionary = {}
	if seconds_needed <= 0.0:
		return plan
	
	var need := seconds_needed
	var buffer := _fuel_buffer_seconds
	
	# If buffer already covers, take nothing.
	if buffer >= need:
		return plan
	
	var remaining := need - buffer
	var fuel_types := _build_fuel_types_in_sources(sources)
	for item in fuel_types:
		if remaining <= 0.0:
			break
		var per := maxf(0.0, item.burn_seconds)
		if per <= 0.0:
			continue
		var have_count := Crafting.count_item_multi(sources, item)
		if have_count <= 0:
			continue
		
		# Take enough items to cover remaining seconds (buffer keeps leftovers, so no "waste").
		var take_items := int(ceili(remaining / per))
		take_items = mini(take_items, have_count)
		if take_items <= 0:
			continue
		plan[item] = int(plan.get(item, 0)) + take_items
		remaining -= float(take_items) * per
	
	return plan


func _apply_auto_fuel_take(plan: Dictionary, sources: Array[Inventory]) -> bool:
	if plan.is_empty():
		return true
	if not Crafting.remove_items_multi(sources, plan):
		return false
	# Add taken fuel into buffer (seconds).
	for item in plan.keys():
		var count: int = int(plan[item])
		_fuel_buffer_seconds += float(count) * maxf(0.0, item.burn_seconds)
	return true


func _consume_from_buffer(seconds_needed: float) -> bool:
	if seconds_needed <= 0.0:
		return true
	if _fuel_buffer_seconds + 1e-6 < seconds_needed:
		return false
	_fuel_buffer_seconds -= seconds_needed
	_fuel_buffer_seconds = maxf(0.0, _fuel_buffer_seconds)
	return true


func _consume_fuel_seconds(seconds_needed: float) -> bool:
	# Legacy path kept for compatibility if someone still uses FuelInventory.
	# Not used in auto-fuel mode.
	return false


func get_fuel_seconds_needed_for_recipe(recipe: CraftRecipe) -> float:
	if recipe == null:
		return 0.0
	if not recipe.requires_fuel:
		return 0.0
	# Минимальная цена, если крафт мгновенный, но требует топлива.
	return maxf(0.1, recipe.craft_time_seconds)


func preview_fuel_consumption(seconds_needed: float) -> Dictionary:
	# Legacy; UI now uses preview_auto_fuel_take.
	return {}


func get_max_job_slots() -> int:
	if station_type != null and station_type.supports_queue:
		return maxi(1, station_type.max_parallel_crafts)
	return 1


func get_pending_job_count() -> int:
	var n := _queue.size()
	if _is_crafting:
		n += 1
	return n


func get_available_job_slots() -> int:
	return maxi(0, get_max_job_slots() - get_pending_job_count())


func can_start_craft(recipe: CraftRecipe, sources: Array[Inventory], _output_inventory: Inventory) -> bool:
	return compute_max_crafts(recipe, sources, true) > 0


func compute_max_crafts(recipe: CraftRecipe, sources: Array[Inventory], respect_queue_slots: bool = true) -> int:
	if recipe == null or not recipe.is_valid():
		return 0
	if station_type == null or recipe.required_station != station_type:
		return 0
	if output_inventory == null or recipe.result == null or recipe.result.item == null or recipe.result.amount <= 0:
		return 0

	var req := Crafting.get_requirements(recipe)
	var max_by_ing := 999999
	for item in req.keys():
		var need := int(req[item])
		if need <= 0:
			continue
		var have := Crafting.count_item_multi(sources, item)
		max_by_ing = mini(max_by_ing, int(floor(float(have) / float(need))))
	if max_by_ing == 999999:
		max_by_ing = 0

	var max_by_fuel := 999999
	if recipe.requires_fuel:
		if station_type == null or not station_type.supports_fuel:
			return 0
		var need_s := get_fuel_seconds_needed_for_recipe(recipe)
		var total_s := get_total_fuel_seconds_available(sources)
		max_by_fuel = int(floor(total_s / need_s)) if need_s > 0.0 else 0

	var upper := mini(max_by_ing, max_by_fuel)
	if upper <= 0:
		return 0

	var lo := 0
	var hi := upper
	while lo < hi:
		var mid := int(ceil((lo + hi) / 2.0))
		if _simulate_output_can_fit_after_queue(recipe.result.item, recipe.result.amount * mid):
			lo = mid
		else:
			hi = mid - 1

	if respect_queue_slots:
		return mini(lo, get_available_job_slots())
	return lo


func start_craft(recipe: CraftRecipe, sources: Array[Inventory], output_inventory: Inventory, preferred_fuel_item: ItemData = null) -> bool:
	return start_craft_many(recipe, sources, output_inventory, preferred_fuel_item, 1) == 1


func start_craft_many(
	recipe: CraftRecipe,
	sources: Array[Inventory],
	_output_inventory: Inventory,
	preferred_fuel_item: ItemData = null,
	times: int = 1
) -> int:
	if times <= 0 or recipe == null or not recipe.is_valid():
		return 0

	var craftable := mini(times, compute_max_crafts(recipe, sources, true))
	if craftable <= 0:
		craft_failed.emit(recipe, "cannot_start")
		return 0

	var per_req := Crafting.get_requirements(recipe)
	var total_req: Dictionary = {}
	for item in per_req.keys():
		total_req[item] = int(per_req[item]) * craftable
	if not Crafting.remove_items_multi(sources, total_req):
		craft_failed.emit(recipe, "no_ingredients")
		return 0

	if recipe.requires_fuel:
		var need_one := get_fuel_seconds_needed_for_recipe(recipe)
		var need_total := need_one * float(craftable)
		var plan := preview_auto_fuel_take(need_total, sources)
		if preferred_fuel_item != null:
			plan = preview_fuel_take_for_specific_item(need_total, sources, preferred_fuel_item)
		if not _apply_auto_fuel_take(plan, sources):
			craft_failed.emit(recipe, "no_fuel_items")
			return 0
		if not _consume_from_buffer(need_total):
			craft_failed.emit(recipe, "no_fuel")
			return 0

	if recipe.start_sound and sfx_player:
		sfx_player.stream = recipe.start_sound
		sfx_player.play()

	for _i in craftable:
		_queue.append({
			"recipe": recipe,
			"time_total": maxf(0.0, recipe.craft_time_seconds),
			"time_left": maxf(0.0, recipe.craft_time_seconds),
		})

	if not _is_crafting:
		_start_next_job()

	craft_state_changed.emit()
	return craftable


func _start_next_job() -> void:
	if _queue.is_empty():
		_active_recipe = null
		_is_crafting = false
		_time_left = 0.0
		_time_total = 0.0
		return
	var job: Dictionary = _queue.pop_front()
	_active_recipe = job["recipe"]
	_time_total = float(job.get("time_total", 0.0))
	_time_left = float(job.get("time_left", 0.0))
	_is_crafting = true
	craft_progress_changed.emit(0.0)


func _process(delta: float) -> void:
	if not _is_crafting:
		return
	if _time_total <= 0.0:
		return
	
	_time_left -= delta
	var p := clampf(1.0 - (_time_left / _time_total), 0.0, 1.0)
	craft_progress_changed.emit(p)
	
	if _time_left <= 0.0:
		_finish_active()


func _finish_active() -> void:
	if _active_recipe == null:
		_cancel_active("missing_recipe")
		return

	# Put result into station output inventory.
	if output_inventory == null:
		_cancel_active("no_output_inventory")
		return
	var ok := output_inventory.add_item(_active_recipe.result.item, _active_recipe.result.amount)
	if not ok:
		_cancel_active("output_full")
		return
	
	if _active_recipe.complete_sound and sfx_player:
		sfx_player.stream = _active_recipe.complete_sound
		sfx_player.play()
	
	if _active_recipe.complete_vfx:
		var vfx := _active_recipe.complete_vfx.instantiate()
		if vfx is Node3D:
			(vfx as Node3D).global_position = global_position + Vector3(0, 1.0, 0)
		add_child(vfx)
	
	var finished := _active_recipe
	_active_recipe = null
	_is_crafting = false
	_time_left = 0.0
	_time_total = 0.0
	
	craft_state_changed.emit()
	craft_progress_changed.emit(1.0)
	craft_completed.emit(finished)
	
	_start_next_job()


func _cancel_active(reason: String) -> void:
	var r := _active_recipe
	_active_recipe = null
	_is_crafting = false
	_time_left = 0.0
	_time_total = 0.0
	craft_state_changed.emit()
	if r != null:
		craft_failed.emit(r, reason)
