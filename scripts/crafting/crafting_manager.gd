class_name CraftingManager
extends Node

signal craft_started(recipe: CraftRecipe)
signal craft_completed(recipe: CraftRecipe)
signal craft_failed(recipe: CraftRecipe, reason: String)

signal personal_craft_started(recipe: CraftRecipe)
signal personal_craft_completed(recipe: CraftRecipe)
signal personal_queue_changed()

var _personal_queue: Array[Dictionary] = []
var _personal_active: Dictionary = {}
var _personal_time_total: float = 0.0
var _personal_time_elapsed: float = 0.0


func _ready() -> void:
	set_process(true)
	print("[CraftingManager] _ready called, _process ENABLED")


func _process(delta: float) -> void:
	if _personal_active.is_empty():
		return
	if _personal_time_total <= 0.0:
		_finish_personal_craft()
		return
	_personal_time_elapsed += delta
	if _personal_time_elapsed >= _personal_time_total:
		_finish_personal_craft()


func _finish_personal_craft() -> void:
	var recipe: CraftRecipe = _personal_active.get("recipe", null)
	var out_inv: Inventory = _personal_active.get("output_inv", null)
	print("[CraftingManager] _finish_personal_craft: recipe=%s elapsed=%.2f total=%.2f" % [
		recipe.id if recipe != null else "null",
		_personal_time_elapsed,
		_personal_time_total,
	])
	if recipe != null and out_inv != null and recipe.result != null and recipe.result.item != null:
		out_inv.add_item(recipe.result.item, recipe.result.amount)
		personal_craft_completed.emit(recipe)
	
	_personal_active = {}
	_personal_time_total = 0.0
	_personal_time_elapsed = 0.0
	personal_queue_changed.emit()
	_start_next_personal_job_if_needed()


func _start_next_personal_job_if_needed() -> void:
	if not _personal_active.is_empty():
		return
	if _personal_queue.is_empty():
		return
	
	_personal_active = _personal_queue.pop_front()
	var recipe: CraftRecipe = _personal_active.get("recipe", null)
	_personal_time_total = maxf(0.0, float(_personal_active.get("time_total", 0.0)))
	_personal_time_elapsed = 0.0
	personal_queue_changed.emit()
	print("[CraftingManager] Starting personal craft: recipe=%s time_total=%.2f" % [
		recipe.id if recipe != null else "null",
		_personal_time_total,
	])
	if recipe != null:
		personal_craft_started.emit(recipe)


func get_personal_active_recipe() -> CraftRecipe:
	return _personal_active.get("recipe", null)


func get_personal_active_progress_0_1() -> float:
	if _personal_active.is_empty():
		return 0.0
	if _personal_time_total <= 0.0:
		return 1.0
	return clampf(_personal_time_elapsed / _personal_time_total, 0.0, 1.0)


func get_requirements(recipe: CraftRecipe) -> Dictionary:
	# Dictionary[ItemData, int]
	var req: Dictionary = {}
	if recipe == null:
		return req
	
	# 1) base ingredients
	for ing in recipe.ingredients:
		if ing == null or ing.item == null or ing.amount <= 0:
			continue
		req[ing.item] = int(req.get(ing.item, 0)) + ing.amount
	
	# 2) upgrade base item is tracked separately in recipe
	if recipe.is_upgrade and recipe.upgrade_consumes_base_item and recipe.upgrade_base_item != null:
		# Avoid double-count if user also added base item as an ingredient.
		if req.has(recipe.upgrade_base_item):
			req[recipe.upgrade_base_item] = maxi(0, int(req[recipe.upgrade_base_item]) - 1)
			if int(req[recipe.upgrade_base_item]) <= 0:
				req.erase(recipe.upgrade_base_item)
		req[recipe.upgrade_base_item] = int(req.get(recipe.upgrade_base_item, 0)) + 1
	
	return req


func count_item(inv: Inventory, item: ItemData) -> int:
	if inv == null or item == null:
		return 0
	var total := 0
	for i in inv.slots_count:
		var stack := inv.get_slot(i)
		if stack != null and stack.item == item:
			total += stack.count
	return total


func count_item_multi(inventories: Array[Inventory], item: ItemData) -> int:
	if item == null:
		return 0
	var total := 0
	for inv in inventories:
		if inv == null:
			continue
		total += count_item(inv, item)
	return total


func has_requirements(inv: Inventory, requirements: Dictionary) -> bool:
	if inv == null:
		return false
	for item in requirements.keys():
		var need: int = int(requirements[item])
		if need <= 0:
			continue
		if count_item(inv, item) < need:
			return false
	return true


func has_requirements_multi(inventories: Array[Inventory], requirements: Dictionary) -> bool:
	if inventories.is_empty():
		return false
	for item in requirements.keys():
		var need: int = int(requirements[item])
		if need <= 0:
			continue
		if count_item_multi(inventories, item) < need:
			return false
	return true


func _simulate_slots(inv: Inventory) -> Array:
	# Returns Array[Dictionary] where each element is:
	# { "item": ItemData, "count": int } or null for empty
	var sim: Array = []
	sim.resize(inv.slots_count)
	for i in inv.slots_count:
		var st := inv.get_slot(i)
		if st == null or st.item == null or st.count <= 0:
			sim[i] = null
		else:
			sim[i] = {"item": st.item, "count": st.count}
	return sim


func _simulate_remove(sim: Array, item: ItemData, amount: int) -> bool:
	var remaining := amount
	for i in sim.size():
		if remaining <= 0:
			break
		var cell = sim[i]
		if cell == null:
			continue
		if cell["item"] != item:
			continue
		var take := mini(int(cell["count"]), remaining)
		cell["count"] = int(cell["count"]) - take
		remaining -= take
		if int(cell["count"]) <= 0:
			sim[i] = null
	return remaining <= 0


func _simulate_add(sim: Array, item: ItemData, amount: int) -> bool:
	var remaining := amount
	# stack into existing
	for i in sim.size():
		if remaining <= 0:
			break
		var cell = sim[i]
		if cell == null:
			continue
		if cell["item"] != item:
			continue
		var space := item.max_stack - int(cell["count"])
		if space <= 0:
			continue
		var added := mini(space, remaining)
		cell["count"] = int(cell["count"]) + added
		remaining -= added
	
	# new stacks into empty slots
	for i in sim.size():
		if remaining <= 0:
			break
		if sim[i] != null:
			continue
		var stack_size := mini(item.max_stack, remaining)
		sim[i] = {"item": item, "count": stack_size}
		remaining -= stack_size
	
	return remaining <= 0


func can_craft(inv: Inventory, recipe: CraftRecipe) -> bool:
	if inv == null or recipe == null or not recipe.is_valid():
		return false
	
	if recipe.result == null or recipe.result.item == null or recipe.result.amount <= 0:
		return false
	
	var req := get_requirements(recipe)
	if not has_requirements(inv, req):
		return false
	
	# Simulate removal + add to ensure capacity after crafting.
	var sim := _simulate_slots(inv)
	for item in req.keys():
		if not _simulate_remove(sim, item, int(req[item])):
			return false
	if not _simulate_add(sim, recipe.result.item, recipe.result.amount):
		return false
	
	return true


func can_craft_multi(inventories: Array[Inventory], recipe: CraftRecipe, output_inventory: Inventory = null) -> bool:
	if inventories.is_empty() or recipe == null or not recipe.is_valid():
		return false
	if recipe.result == null or recipe.result.item == null or recipe.result.amount <= 0:
		return false
	
	var req := get_requirements(recipe)
	if not has_requirements_multi(inventories, req):
		return false
	
	# Output goes to a specific inventory (defaults to first valid).
	var out_inv := output_inventory
	if out_inv == null:
		for inv in inventories:
			if inv != null:
				out_inv = inv
				break
	if out_inv == null:
		return false
	
	# Simulate space only in the output inventory.
	# We remove from sources (doesn't change output space), then add to output.
	var sim := _simulate_slots(out_inv)
	if not _simulate_add(sim, recipe.result.item, recipe.result.amount):
		return false
	return true


func can_fit_amount(inv: Inventory, item: ItemData, amount: int) -> bool:
	if inv == null or item == null or amount <= 0:
		return false
	var sim := _simulate_slots(inv)
	return _simulate_add(sim, item, amount)


func _remove_items(inv: Inventory, requirements: Dictionary) -> bool:
	if inv == null:
		return false
	
	# Verify first (prevents partial removals).
	if not has_requirements(inv, requirements):
		return false
	
	for item in requirements.keys():
		var remaining: int = int(requirements[item])
		if remaining <= 0:
			continue
		
		for i in inv.slots_count:
			if remaining <= 0:
				break
			var st := inv.get_slot(i)
			if st == null or st.item != item:
				continue
			
			var take := mini(st.count, remaining)
			st.count -= take
			remaining -= take
			if st.count <= 0:
				inv.clear_slot(i)
		
		if remaining > 0:
			# Should be impossible due to pre-check, but keep safety.
			return false
	
	inv.changed.emit()
	return true


func _remove_items_multi(inventories: Array[Inventory], requirements: Dictionary) -> bool:
	if inventories.is_empty():
		return false
	if not has_requirements_multi(inventories, requirements):
		return false
	
	# Remove items across inventories in order.
	for item in requirements.keys():
		var remaining: int = int(requirements[item])
		if remaining <= 0:
			continue
		
		for inv in inventories:
			if inv == null:
				continue
			for i in inv.slots_count:
				if remaining <= 0:
					break
				var st := inv.get_slot(i)
				if st == null or st.item != item:
					continue
				
				var take := mini(st.count, remaining)
				st.count -= take
				remaining -= take
				if st.count <= 0:
					inv.clear_slot(i)
			
			if remaining <= 0:
				break
		
		if remaining > 0:
			return false
	
	for inv in inventories:
		if inv != null:
			inv.changed.emit()
	return true


func remove_items_multi(inventories: Array[Inventory], requirements: Dictionary) -> bool:
	return _remove_items_multi(inventories, requirements)


func craft(inv: Inventory, recipe: CraftRecipe) -> bool:
	if inv == null or recipe == null:
		return false
	
	if not recipe.is_valid():
		craft_failed.emit(recipe, "invalid_recipe")
		return false
	
	if not can_craft(inv, recipe):
		craft_failed.emit(recipe, "requirements_or_space")
		return false
	
	craft_started.emit(recipe)
	
	var req := get_requirements(recipe)
	if not _remove_items(inv, req):
		craft_failed.emit(recipe, "remove_failed")
		return false
	
	var ok := inv.add_item(recipe.result.item, recipe.result.amount)
	if not ok:
		# Should not happen because we simulated capacity, but keep safety.
		craft_failed.emit(recipe, "add_failed")
		return false
	
	craft_completed.emit(recipe)
	return true


func craft_multi(inventories: Array[Inventory], recipe: CraftRecipe, output_inventory: Inventory = null) -> bool:
	if inventories.is_empty() or recipe == null:
		return false
	if not recipe.is_valid():
		craft_failed.emit(recipe, "invalid_recipe")
		return false
	
	var out_inv := output_inventory
	if out_inv == null:
		for inv in inventories:
			if inv != null:
				out_inv = inv
				break
	if out_inv == null:
		craft_failed.emit(recipe, "no_output_inventory")
		return false
	
	if not can_craft_multi(inventories, recipe, out_inv):
		craft_failed.emit(recipe, "requirements_or_space")
		return false
	
	craft_started.emit(recipe)
	
	var req := get_requirements(recipe)
	if not _remove_items_multi(inventories, req):
		craft_failed.emit(recipe, "remove_failed")
		return false
	
	var ok := out_inv.add_item(recipe.result.item, recipe.result.amount)
	if not ok:
		craft_failed.emit(recipe, "add_failed")
		return false
	
	craft_completed.emit(recipe)
	return true


func enqueue_personal_craft(recipe: CraftRecipe, sources: Array[Inventory], output_inv: Inventory) -> bool:
	if recipe == null or not recipe.is_valid():
		return false
	if output_inv == null:
		return false
	# Personal crafting does not support fuel (no station buffer).
	if recipe.requires_fuel:
		return false
	
	var req := get_requirements(recipe)
	if not has_requirements_multi(sources, req):
		return false
	if not can_fit_amount(output_inv, recipe.result.item, recipe.result.amount):
		return false
	
	# Consume ingredients immediately.
	if not remove_items_multi(sources, req):
		return false
	
	print("[CraftingManager] enqueue_personal_craft: recipe=%s craft_time_seconds=%.2f" % [recipe.id, recipe.craft_time_seconds])
	var job := {
		"recipe": recipe,
		"time_total": maxf(0.0, float(recipe.craft_time_seconds)),
		"output_inv": output_inv,
	}
	_personal_queue.append(job)
	personal_queue_changed.emit()
	_start_next_personal_job_if_needed()
	return true
