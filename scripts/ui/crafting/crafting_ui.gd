class_name CraftingUI
extends Control

@export var recipes_dir: String = "res://resources/crafting/recipes"

var player: Player
var inventory: Inventory
var extra_inventories: Array[Inventory] = []
var station_filter: CraftingStationType = null
var station: CraftingStation = null

var _all_recipes: Array[CraftRecipe] = []
var _visible_recipes: Array[CraftRecipe] = []
var _selected_recipe: CraftRecipe = null
var _selected_category: String = "Все"
var _fuel_choice_items: Array[ItemData] = []  # index -> ItemData (for OptionButton items after "Авто")
var _preferred_fuel_item: ItemData = null
var _fuel_choice_user_locked: bool = false

@onready var root_panel: PanelContainer = $Panel
@onready var category_list: ItemList = $Panel/Margin/Root/Left/Categories/CategoryList
@onready var recipe_list: ItemList = $Panel/Margin/Root/Left/RecipeList

@onready var result_icon: TextureRect = $Panel/Margin/Root/Right/TopRow/ResultIcon
@onready var recipe_title: Label = $Panel/Margin/Root/Right/TopRow/RecipeTitle
@onready var recipe_desc: Label = $Panel/Margin/Root/Right/RecipeDesc
@onready var ingredients_box: VBoxContainer = $Panel/Margin/Root/Right/IngredientsPanel/IngredientsMargin/Ingredients
@onready var fuel_panel: PanelContainer = $Panel/Margin/Root/Right/FuelPanel
@onready var fuel_list: ItemList = $Panel/Margin/Root/Right/FuelPanel/FuelMargin/Fuel/FuelList
@onready var fuel_details: VBoxContainer = $Panel/Margin/Root/Right/FuelPanel/FuelMargin/Fuel/FuelDetails
@onready var result_label: Label = $Panel/Margin/Root/Right/Result
@onready var craft_time_label: Label = $Panel/Margin/Root/Right/CraftTime
@onready var craft_button: Button = $Panel/Margin/Root/Right/Buttons/Craft1
@onready var craft5_button: Button = $Panel/Margin/Root/Right/Buttons/Craft5
@onready var craft10_button: Button = $Panel/Margin/Root/Right/Buttons/Craft10
@onready var progress: ProgressBar = $Panel/Margin/Root/Right/Progress
@onready var status_label: Label = $Panel/Margin/Root/Right/Status
@onready var close_button: Button = $Panel/Margin/Root/Right/TopRow/CloseButton
@onready var queue_panel: PanelContainer = $Panel/Margin/Root/Right/QueuePanel
@onready var queue_list: ItemList = $Panel/Margin/Root/Right/QueuePanel/QueueMargin/Queue/QueueList
@onready var cancel_queued_button: Button = $Panel/Margin/Root/Right/QueuePanel/QueueMargin/Queue/CancelQueued

const CATEGORY_NAMES: Array[String] = [
	"Все",
	"Инструменты",
	"Оружие",
	"Броня и экипировка",
	"Еда и вода",
	"Расходуемые предметы",
	"Промежуточные материалы",
	"Станции и мебель",
	"Декор и полезные объекты",
]


func setup(p_player: Player, p_inventory: Inventory, p_station_filter: CraftingStationType = null, p_extra_inventories: Array[Inventory] = [], p_station: CraftingStation = null) -> void:
	player = p_player
	inventory = p_inventory
	station_filter = p_station_filter
	extra_inventories = p_extra_inventories
	station = p_station


func _ready() -> void:
	add_to_group("inventory_ui")
	mouse_filter = Control.MOUSE_FILTER_PASS
	z_index = 10
	
	_build_categories()
	_load_recipes()
	_apply_filters()
	_wire_events()
	_render_selected()
	_bind_station()
	Crafting.personal_craft_completed.connect(_on_personal_craft_completed)
	Crafting.personal_queue_changed.connect(_on_personal_queue_changed)
	_on_personal_queue_changed()


func _process(_delta: float) -> void:
	if station != null:
		return
	var active := Crafting.get_personal_active_recipe()
	if active != null:
		progress.visible = true
		progress.value = Crafting.get_personal_active_progress_0_1()
		status_label.text = "Крафт: %d%%" % int(progress.value * 100.0)
	else:
		if progress.visible and progress.value > 0.0:
			progress.visible = false
			progress.value = 0


func _on_personal_craft_completed(_recipe: CraftRecipe) -> void:
	if station != null:
		return
	progress.visible = false
	progress.value = 0
	status_label.text = "Готово!"
	_refresh_recipe_list_labels()
	_render_selected()
	_on_personal_queue_changed()


func _on_personal_queue_changed() -> void:
	if queue_panel == null or not is_instance_valid(queue_panel):
		return
	# Personal queue UI only (no station)
	var is_personal := (station == null or not is_instance_valid(station))
	queue_panel.visible = is_personal
	if not is_personal:
		return
	if queue_list == null or not is_instance_valid(queue_list):
		return
	queue_list.clear()
	var snap := Crafting.get_personal_queue_snapshot()
	if snap.is_empty():
		queue_list.add_item("Пусто")
		queue_list.set_item_disabled(0, true)
		cancel_queued_button.disabled = true
		return
	for i in snap.size():
		var job: Dictionary = snap[i]
		var r: CraftRecipe = job.get("recipe", null)
		var label := ""
		if i == 0 and Crafting.get_personal_active_recipe() != null:
			var left := Crafting.get_personal_active_time_left()
			label = "[В работе] %s (осталось: %.1f c)" % [r.get_label() if r != null else "?", left]
		else:
			label = "%s" % [r.get_label() if r != null else "?"]
		var idx := queue_list.add_item(label)
		if r != null and r.result != null and r.result.item != null and r.result.item.icon != null:
			queue_list.set_item_icon(idx, r.result.item.icon)
	cancel_queued_button.disabled = false


func _wire_events() -> void:
	category_list.item_selected.connect(_on_category_selected)
	recipe_list.item_selected.connect(_on_recipe_selected)
	craft_button.pressed.connect(_on_craft_1)
	craft5_button.pressed.connect(_on_craft_5)
	craft10_button.pressed.connect(_on_craft_10)
	fuel_list.item_selected.connect(_on_fuel_selected)
	close_button.pressed.connect(_on_close_pressed)
	cancel_queued_button.pressed.connect(_on_cancel_selected_queue)


func _bind_station() -> void:
	if station == null:
		return
	if not is_instance_valid(station):
		station = null
		return
	station.craft_progress_changed.connect(_on_station_progress_changed)
	station.craft_state_changed.connect(_on_station_state_changed)
	station.craft_completed.connect(_on_station_completed)
	station.craft_failed.connect(_on_station_failed)


func _on_category_selected(idx: int) -> void:
	if idx < 0 or idx >= CATEGORY_NAMES.size():
		_selected_category = "Все"
	else:
		_selected_category = CATEGORY_NAMES[idx]
	_apply_filters()


func _on_recipe_selected(idx: int) -> void:
	if idx < 0 or idx >= _visible_recipes.size():
		_selected_recipe = null
	else:
		_selected_recipe = _visible_recipes[idx]
	_fuel_choice_user_locked = false
	_render_selected()


func _on_fuel_selected(idx: int) -> void:
	_fuel_choice_user_locked = true
	_update_preferred_fuel_from_list(idx)
	_render_selected()


func _on_craft_1() -> void:
	_try_craft(1)


func _on_craft_5() -> void:
	_try_craft(5)


func _on_craft_10() -> void:
	_try_craft(15)


func _on_cancel_selected_queue() -> void:
	if station != null and is_instance_valid(station):
		return
	if queue_list == null or not is_instance_valid(queue_list):
		return
	var selected := queue_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = int(selected[0])
	# If list shows "Пусто" disabled item, ignore.
	if queue_list.is_item_disabled(idx):
		return
	# Refund targets: prefer player's main inventory first, then extra inventories (hotbar).
	var refund_targets: Array[Inventory] = []
	if inventory != null:
		refund_targets.append(inventory)
	for inv2 in extra_inventories:
		if inv2 != null:
			refund_targets.append(inv2)
	var ok := Crafting.cancel_personal_job(idx, refund_targets)
	if ok:
		status_label.text = "Отменено (ресурсы возвращены)"
	else:
		status_label.text = "Не удалось отменить"
	_on_personal_queue_changed()


func _on_close_pressed() -> void:
	# If opened from a station, close all related windows (crafting + output + player inventory).
	if player != null and station != null and is_instance_valid(station) and player.has_method("close_all_ui"):
		player.close_all_ui()
		return
	queue_free()


func _on_station_progress_changed(p: float) -> void:
	progress.visible = true
	progress.value = p


func _on_station_state_changed() -> void:
	_refresh_recipe_list_labels()
	_render_selected()


func _on_station_completed(_r: CraftRecipe) -> void:
	status_label.text = "Готово"
	_refresh_recipe_list_labels()
	_render_selected()


func _on_station_failed(_r: CraftRecipe, reason: String) -> void:
	status_label.text = "Ошибка: " + reason
	_refresh_recipe_list_labels()
	_render_selected()


func _build_categories() -> void:
	category_list.clear()
	for c in CATEGORY_NAMES:
		category_list.add_item(c)
	category_list.select(0)
	_selected_category = "Все"


func _load_recipes() -> void:
	_all_recipes.clear()
	
	var dir := DirAccess.open(recipes_dir)
	if dir == null:
		status_label.text = "Не найдена папка рецептов: " + recipes_dir
		return
	
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
			continue
		var path := recipes_dir.path_join(file_name)
		var res := load(path)
		if res is CraftRecipe:
			_all_recipes.append(res)
	
	_all_recipes.sort_custom(func(a: CraftRecipe, b: CraftRecipe) -> bool:
		return a.get_label().to_lower() < b.get_label().to_lower()
	)


func _apply_filters() -> void:
	_visible_recipes.clear()
	recipe_list.clear()
	
	for r in _all_recipes:
		if r == null:
			continue
		# If menu opened "без станции" (K), show only basic recipes explicitly allowed.
		if station_filter == null and (station == null or not is_instance_valid(station)):
			if not r.allow_without_station:
				continue
		if station_filter != null and r.required_station != station_filter:
			continue
		if _selected_category != "Все" and r.recipe_category != _selected_category:
			continue
		_visible_recipes.append(r)
		var idx := recipe_list.add_item(_recipe_list_label(r))
		var icon := _get_recipe_icon(r)
		if icon != null:
			recipe_list.set_item_icon(idx, icon)
	
	if _visible_recipes.is_empty():
		_selected_recipe = null
	else:
		_selected_recipe = _visible_recipes[0]
		recipe_list.select(0)
	
	_render_selected()


func _render_selected() -> void:
	# Progress is controlled by station when crafting with time
	if station == null or not is_instance_valid(station) or not station.is_busy():
		# If crafting without station, show personal progress (if active).
		if station == null:
			var active := Crafting.get_personal_active_recipe()
			if active != null:
				progress.visible = true
				progress.value = Crafting.get_personal_active_progress_0_1()
			else:
				progress.visible = false
				progress.value = 0
		else:
			progress.visible = false
			progress.value = 0
	status_label.text = ""
	_clear_ingredients()
	_clear_fuel()
	
	if _selected_recipe == null:
		recipe_title.text = "Рецепт не выбран"
		recipe_desc.text = ""
		result_icon.texture = null
		result_label.text = ""
		craft_time_label.text = ""
		_set_buttons_enabled(false)
		fuel_panel.visible = false
		return
	
	recipe_title.text = _selected_recipe.get_label()
	recipe_desc.text = _selected_recipe.description
	craft_time_label.text = "Время: %.1f c" % _selected_recipe.craft_time_seconds
	
	if _selected_recipe.result != null and _selected_recipe.result.item != null:
		var amount := _selected_recipe.result.amount
		result_label.text = "Результат: %s x%d" % [_selected_recipe.result.item.display_name, amount]
		result_icon.texture = _selected_recipe.result.item.icon
	else:
		result_label.text = "Результат: (не задан)"
		result_icon.texture = null
	
	_build_ingredients_rows(_selected_recipe)
	_build_fuel_rows(_selected_recipe)
	_build_max_crafts_row(_selected_recipe)
	_refresh_recipe_list_labels()
	
	var can := false
	if inventory != null:
		var sources: Array[Inventory] = [inventory]
		for inv2 in extra_inventories:
			if inv2 != null:
				sources.append(inv2)
		
		if station != null and is_instance_valid(station):
			can = station.compute_max_crafts(_selected_recipe, sources, true) > 0
		else:
			can = _compute_max_crafts_now(_selected_recipe, sources, inventory) > 0
	_set_buttons_enabled(can)
	if not can:
		if station != null and is_instance_valid(station) \
				and _compute_max_crafts_for_recipe(_selected_recipe) > 0 \
				and station.get_available_job_slots() <= 0:
			status_label.text = "Очередь заполнена (макс. %d)" % station.get_max_job_slots()
		else:
			status_label.text = "Не хватает ингредиентов / нет места / нет топлива"


func _set_buttons_enabled(v: bool) -> void:
	craft_button.disabled = not v
	craft5_button.disabled = not v
	craft10_button.disabled = not v


func _clear_ingredients() -> void:
	for c in ingredients_box.get_children():
		c.queue_free()


func _clear_fuel() -> void:
	# Don't free FuelList itself; only clear dynamic details.
	for c in fuel_details.get_children():
		c.queue_free()
	if fuel_list and is_instance_valid(fuel_list):
		fuel_list.clear()


func _build_fuel_rows(r: CraftRecipe) -> void:
	if r == null:
		fuel_panel.visible = false
		return
	if station == null or not is_instance_valid(station):
		fuel_panel.visible = false
		return
	if not r.requires_fuel:
		fuel_panel.visible = false
		return
	
	fuel_panel.visible = true
	
	var need_s := station.get_fuel_seconds_needed_for_recipe(r)
	var buffer_s := station.get_fuel_buffer_seconds()
	
	var sources: Array[Inventory] = []
	if inventory != null:
		sources.append(inventory)
	for inv2 in extra_inventories:
		if inv2 != null:
			sources.append(inv2)
	
	_setup_fuel_list(sources, need_s, buffer_s)
	
	var header := Label.new()
	header.text = "Топливо"
	header.add_theme_font_size_override("font_size", 18)
	fuel_details.add_child(header)
	
	var total_fuel_s := station.get_total_fuel_seconds_available(sources)
	var summary := Label.new()
	summary.text = "Нужно: %.1f c • В буфере: %.1f c • В инвентаре/хотбаре: %.1f c" % [need_s, buffer_s, maxf(0.0, total_fuel_s - buffer_s)]
	summary.modulate = Color(0.45, 1.0, 0.45) if (total_fuel_s >= need_s) else Color(1.0, 0.45, 0.45)
	fuel_details.add_child(summary)
	
	var plan := station.preview_auto_fuel_take(need_s, sources)
	if _preferred_fuel_item != null:
		plan = station.preview_fuel_take_for_specific_item(need_s, sources, _preferred_fuel_item)
	if plan.is_empty():
		if buffer_s >= need_s:
			var ok_lbl := Label.new()
			ok_lbl.text = "Списания предметов не будет: топлива в буфере уже достаточно."
			fuel_details.add_child(ok_lbl)
			return
		# If not enough buffer, but plan is empty => no fuel items in player inventories.
		var hint := Label.new()
		hint.text = "Не найдено подходящее топливо в инвентаре/хотбаре (нужны предметы с burn_seconds > 0)."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fuel_details.add_child(hint)
		return

	var plan_header := Label.new()
	plan_header.text = "Будет списано как топливо:"
	plan_header.add_theme_font_size_override("font_size", 14)
	fuel_details.add_child(plan_header)
	
	var keys := plan.keys()
	keys.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.display_name.to_lower() < b.display_name.to_lower()
	)
	
	for item in keys:
		var take: int = int(plan[item])
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(22, 22)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = item.icon
		row.add_child(icon)
		
		var name_lbl := Label.new()
		name_lbl.text = item.display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		
		var count_lbl := Label.new()
		count_lbl.text = "x%d" % take
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count_lbl)
		
		fuel_details.add_child(row)


func _build_max_crafts_row(r: CraftRecipe) -> void:
	if r == null:
		return
	if inventory == null:
		return
	var max_count := _compute_max_crafts_for_recipe(r)
	
	var lbl := Label.new()
	lbl.text = "Максимум можно скрафтить сейчас: %d" % max_count
	lbl.modulate = Color(0.85, 0.85, 0.85)
	if fuel_panel.visible:
		fuel_details.add_child(lbl)
	else:
		ingredients_box.add_child(lbl)


func _recipe_list_label(r: CraftRecipe) -> String:
	var label := r.get_label()
	if inventory == null:
		return label
	return "%s (%d)" % [label, _compute_max_crafts_for_recipe(r)]


func _get_craft_sources() -> Array[Inventory]:
	var sources: Array[Inventory] = []
	if inventory != null:
		sources.append(inventory)
	for inv2 in extra_inventories:
		if inv2 != null:
			sources.append(inv2)
	return sources


func _compute_max_crafts_for_recipe(r: CraftRecipe) -> int:
	if inventory == null or r == null:
		return 0
	var sources := _get_craft_sources()
	if station != null and is_instance_valid(station):
		return station.compute_max_crafts(r, sources, false)
	return _compute_max_crafts_now(r, sources, inventory)


func _refresh_recipe_list_labels() -> void:
	for i in _visible_recipes.size():
		recipe_list.set_item_text(i, _recipe_list_label(_visible_recipes[i]))


func _compute_max_crafts_now(r: CraftRecipe, sources: Array[Inventory], output_inv: Inventory) -> int:
	if r == null or not r.is_valid():
		return 0
	if r.result == null or r.result.item == null or r.result.amount <= 0:
		return 0
	if output_inv == null:
		return 0
	
	# 1) By ingredients
	var req := Crafting.get_requirements(r)
	var max_by_ing := 999999
	for item in req.keys():
		var need := int(req[item])
		if need <= 0:
			continue
		var have := Crafting.count_item_multi(sources, item)
		max_by_ing = mini(max_by_ing, int(floor(float(have) / float(need))))
	if max_by_ing == 999999:
		max_by_ing = 0
	
	# 2) By fuel
	var max_by_fuel: int = 999999
	if station != null and is_instance_valid(station) and r.requires_fuel:
		var need_s := station.get_fuel_seconds_needed_for_recipe(r)
		var total_s := station.get_total_fuel_seconds_available(sources)
		max_by_fuel = int(floor(total_s / need_s)) if need_s > 0.0 else 0
	
	var upper: int = mini(max_by_ing, max_by_fuel)
	if upper <= 0:
		return 0
	
	# 3) By output space (binary search)
	var lo: int = 0
	var hi: int = upper
	while lo < hi:
		var mid := int(ceil((lo + hi) / 2.0))
		var ok := Crafting.can_fit_amount(output_inv, r.result.item, r.result.amount * mid)
		if ok:
			lo = mid
		else:
			hi = mid - 1
	return lo


func _build_ingredients_rows(r: CraftRecipe) -> void:
	var header := Label.new()
	header.text = "Ингредиенты"
	header.add_theme_font_size_override("font_size", 18)
	ingredients_box.add_child(header)
	
	var req := Crafting.get_requirements(r)
	var keys := req.keys()
	keys.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.display_name.to_lower() < b.display_name.to_lower()
	)
	
	for item in keys:
		var need: int = int(req[item])
		var have: int = count_item_safe(inventory, item)
		if not extra_inventories.is_empty():
			var sources2: Array[Inventory] = [inventory]
			for inv2 in extra_inventories:
				if inv2 != null:
					sources2.append(inv2)
			have = Crafting.count_item_multi(sources2, item)
		var ok := have >= need
		
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = item.icon
		row.add_child(icon)
		
		var name_lbl := Label.new()
		name_lbl.text = item.display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		
		var count_lbl := Label.new()
		count_lbl.text = "x%d / x%d" % [have, need]
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count_lbl)
		
		var tint := Color(0.45, 1.0, 0.45) if ok else Color(1.0, 0.45, 0.45)
		name_lbl.modulate = tint
		count_lbl.modulate = tint
		
		ingredients_box.add_child(row)


func count_item_safe(inv: Inventory, item: ItemData) -> int:
	if inv == null:
		return 0
	return Crafting.count_item(inv, item)

func _get_recipe_icon(r: CraftRecipe) -> Texture2D:
	if r == null:
		return null
	if r.result != null and r.result.item != null:
		return r.result.item.icon
	return null


func _try_craft(times: int) -> void:
	if inventory == null or _selected_recipe == null:
		return
	
	var sources: Array[Inventory] = [inventory]
	for inv2 in extra_inventories:
		if inv2 != null:
			sources.append(inv2)

	if station != null and is_instance_valid(station):
		var started := station.start_craft_many(_selected_recipe, sources, inventory, _preferred_fuel_item, times)
		status_label.text = ("В очереди: x%d" % started) if started > 0 else "Крафт не запущен"
		_refresh_recipe_list_labels()
		_render_selected()
		return
	
	# Без станции: ставим в личную очередь (таймер работает в фоне)
	var queued := Crafting.enqueue_personal_craft_many(_selected_recipe, sources, inventory, times)
	status_label.text = ("В очереди: x%d" % queued) if queued > 0 else "Не удалось добавить в очередь"
	_refresh_recipe_list_labels()
	_render_selected()
	_on_personal_queue_changed()


func _setup_fuel_list(sources: Array[Inventory], need_s: float, buffer_s: float) -> void:
	fuel_list.clear()
	_fuel_choice_items.clear()
	fuel_list.add_item("Авто (оптимально)", null)
	fuel_list.set_item_metadata(0, null)
	
	# Collect available fuel items (burn_seconds > 0)
	var fuel_items: Array[ItemData] = []
	for inv in sources:
		if inv == null:
			continue
		for i in inv.slots_count:
			var st := inv.get_slot(i)
			if st == null or st.item == null or st.count <= 0:
				continue
			if st.item.burn_seconds <= 0.0:
				continue
			if not fuel_items.has(st.item):
				fuel_items.append(st.item)
	
	fuel_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.burn_seconds < b.burn_seconds
	)
	
	for it in fuel_items:
		_fuel_choice_items.append(it)
		var have := Crafting.count_item_multi(sources, it)
		var label := "%s  (есть x%d, %.0fс/шт)" % [it.display_name, have, it.burn_seconds]
		var idx := fuel_list.add_item(label, it.icon)
		fuel_list.set_item_metadata(idx, it)
	
	# Auto-select optimal unless user locked choice.
	if _fuel_choice_user_locked:
		# Keep current preferred if still present; otherwise unlock and reselect.
		if _preferred_fuel_item != null:
			for i in fuel_list.item_count:
				if fuel_list.get_item_metadata(i) == _preferred_fuel_item:
					fuel_list.select(i)
					return
		else:
			# User selected "Auto" previously.
			fuel_list.select(0)
			return
		_fuel_choice_user_locked = false
	
	_preferred_fuel_item = null
	if fuel_list.item_count <= 0:
		return
	
	var remaining := maxf(0.0, need_s - buffer_s)
	if remaining <= 0.0:
		# Buffer is enough; keep Auto.
		fuel_list.select(0)
		return
	
	var best_i := 0
	var best_leftover := INF
	for i in _fuel_choice_items.size():
		var item := _fuel_choice_items[i]
		var have := Crafting.count_item_multi(sources, item)
		var take := int(ceili(remaining / item.burn_seconds))
		if take > have:
			continue
		var leftover := float(take) * item.burn_seconds - remaining
		if leftover < best_leftover:
			best_leftover = leftover
			best_i = i
	
	# +1 because 0 is Auto row.
	fuel_list.select(best_i + 1)
	_preferred_fuel_item = _fuel_choice_items[best_i]


func _update_preferred_fuel_from_list(selected_index: int) -> void:
	if selected_index <= 0:
		_preferred_fuel_item = null
		return
	var arr_idx := selected_index - 1
	if arr_idx < 0 or arr_idx >= _fuel_choice_items.size():
		_preferred_fuel_item = null
		return
	_preferred_fuel_item = _fuel_choice_items[arr_idx]
