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


func can_start_craft(recipe: CraftRecipe, sources: Array[Inventory], output_inventory: Inventory) -> bool:
	if recipe == null or not recipe.is_valid():
		return false
	if station_type == null or recipe.required_station != station_type:
		return false
	if _is_crafting:
		return false
	
	# We take ingredients/fuel immediately, and result goes to station output.
	if not Crafting.has_requirements_multi(sources, Crafting.get_requirements(recipe)):
		return false
	if self.output_inventory == null:
		return false
	if recipe.result == null or recipe.result.item == null:
		return false
	if not _simulate_output_can_fit_after_queue(recipe.result.item, recipe.result.amount):
		return false
	
	if recipe.requires_fuel:
		if station_type == null or not station_type.supports_fuel:
			return false
		var need := get_fuel_seconds_needed_for_recipe(recipe)
		var total_available := _fuel_buffer_seconds + _count_fuel_seconds_in_sources(sources)
		return total_available >= need
	
	return true


func start_craft(recipe: CraftRecipe, sources: Array[Inventory], output_inventory: Inventory, preferred_fuel_item: ItemData = null) -> bool:
	if not can_start_craft(recipe, sources, output_inventory):
		craft_failed.emit(recipe, "cannot_start")
		return false

	# 1) Immediately consume ingredients (so crafting can continue in background).
	var req := Crafting.get_requirements(recipe)
	if not Crafting.remove_items_multi(sources, req):
		craft_failed.emit(recipe, "no_ingredients")
		return false
	
	if recipe.start_sound and sfx_player:
		sfx_player.stream = recipe.start_sound
		sfx_player.play()
	
	# 2) Fuel: consume upfront into buffer then seconds from buffer.
	if recipe.requires_fuel:
		var need := get_fuel_seconds_needed_for_recipe(recipe)
		var plan := preview_auto_fuel_take(need, sources)
		if preferred_fuel_item != null:
			plan = preview_fuel_take_for_specific_item(need, sources, preferred_fuel_item)
		if not _apply_auto_fuel_take(plan, sources):
			_cancel_active("no_fuel_items")
			return false
		if not _consume_from_buffer(need):
			_cancel_active("no_fuel")
			return false

	# 3) Enqueue job
	var job := {
		"recipe": recipe,
		"time_total": maxf(0.0, recipe.craft_time_seconds),
		"time_left": maxf(0.0, recipe.craft_time_seconds),
	}
	_queue.append(job)
	
	# If nothing active, start next immediately
	if not _is_crafting:
		_start_next_job()
	
	craft_state_changed.emit()
	return true


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
