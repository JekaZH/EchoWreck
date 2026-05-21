class_name ItemTooltip
extends Control

@onready var name_label: Label = $Background/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var type_label: Label = $Background/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/TypeLabel
@onready var icon_rect: TextureRect = $Background/MarginContainer/VBoxContainer/HBoxContainer/Icon
@onready var description_label: Label = $Background/MarginContainer/VBoxContainer/DescriptionLabel
@onready var stats_container: VBoxContainer = $Background/MarginContainer/VBoxContainer/StatsContainer
@onready var background: Control = $Background
@onready var content: Control = $Background/MarginContainer

var is_ready := false

func _ready():
	is_ready = true
	hide()

func show_tooltip(item: ItemData, compare_item: ItemData = null):
	if not item:
		hide()
		return

	# Название с цветом редкости
	name_label.text = item.display_name
	name_label.add_theme_color_override("font_color", item.get_rarity_color())

	type_label.text = item.category
	icon_rect.texture = item.icon
	description_label.text = item.description if item.description else "Нет описания"

	# Очищаем старые строки
	for child in stats_container.get_children():
		child.queue_free()

	# Инструмент
	if item.tool_type != "":
		add_stat_line("Инструмент", item.tool_type.capitalize(), Color.LIGHT_BLUE)

	# Урон по блокам (для инструментов)
	if item.block_damage > 0:
		add_stat_line("Урон по блокам", "+" + str(item.block_damage), Color.ORANGE)

	# Урон по существам (для оружия)
	if item.entity_damage > 0:
		add_stat_line("Урон по врагам", "+" + str(item.entity_damage), Color.ORANGE)

	# Эффекты из массива
	for effect in item.effects:
		add_effect_line(effect)
	
	# Equipment stats + comparison (AAA-like)
	if item.is_equipment:
		_add_equipment_comparison(item, compare_item)

	show()
	call_deferred("_fit_background")

func _add_equipment_comparison(item: ItemData, compare_item: ItemData) -> void:
	# Build union of keys (flat + multipliers + armor_value)
	var keys: Array[String] = []
	
	keys.append("armor_value")
	for k in item.stat_additives.keys():
		if not keys.has(str(k)):
			keys.append(str(k))
	for m in item.stat_multipliers.keys():
		if not keys.has(str(m)):
			keys.append(str(m))
	
	if compare_item:
		for k2 in compare_item.stat_additives.keys():
			if not keys.has(str(k2)):
				keys.append(str(k2))
		for m2 in compare_item.stat_multipliers.keys():
			if not keys.has(str(m2)):
				keys.append(str(m2))
	
	# Nice ordering for common stats
	var preferred := ["armor_value","max_health","max_hunger","max_thirst","max_energy","weight_reduction","extra_hotbar_slots","block_damage_bonus","entity_damage",
		"movement_speed","attack_speed","harvest_speed","crafting_speed",
		"hunger_decrease","thirst_decrease","energy_decrease"]
	keys.sort_custom(func(a, b):
		var ia := preferred.find(a)
		var ib := preferred.find(b)
		if ia == -1 and ib == -1:
			return a < b
		if ia == -1:
			return false
		if ib == -1:
			return true
		return ia < ib
	)
	
	if compare_item:
		add_stat_line("Сравнение", "Ctrl", Color(1, 1, 1, 0.7))
	
	for key in keys:
		var is_mult := item.stat_multipliers.has(key) or (compare_item and compare_item.stat_multipliers.has(key))
		var new_v: float = 0.0
		var old_v: float = 0.0
		
		if key == "armor_value":
			new_v = float(item.armor_value)
			old_v = float(compare_item.armor_value) if compare_item else 0.0
		elif is_mult:
			new_v = float(item.stat_multipliers.get(key, 1.0))
			old_v = float(compare_item.stat_multipliers.get(key, 1.0)) if compare_item else 1.0
		else:
			new_v = float(item.stat_additives.get(key, 0.0))
			old_v = float(compare_item.stat_additives.get(key, 0.0)) if compare_item else 0.0
		
		# Skip pure zeros if no comparison
		if compare_item == null and abs(new_v) < 0.0001 and not is_mult:
			continue
		if compare_item == null and is_mult and abs(new_v - 1.0) < 0.0001:
			continue
		
		var delta: float = new_v - old_v
		var better := _is_delta_better(key, delta, is_mult)
		
		var color := Color(1, 1, 1, 0.85)
		if compare_item:
			if abs(delta) < 0.0001:
				color = Color(1, 1, 1, 0.65)
			else:
				color = Color(0.35, 1.0, 0.55, 1.0) if better else Color(1.0, 0.35, 0.35, 1.0)
		else:
			# base display: positive green, negative red
			if is_mult:
				color = Color(1, 1, 1, 0.85)
			else:
				color = Color(0.35, 1.0, 0.55, 1.0) if new_v > 0 else (Color(1.0, 0.35, 0.35, 1.0) if new_v < 0 else Color(1,1,1,0.65))
		
		var label := _pretty_stat_name(key)
		var value_text := ""
		
		if is_mult:
			# Show as percent, e.g. 0.95 -> -5%
			var new_pct := (new_v - 1.0) * 100.0
			value_text = ("%+.0f%%" % new_pct)
			if compare_item:
				var old_pct := (old_v - 1.0) * 100.0
				var d_pct := (delta) * 100.0
				value_text += " (сейчас %+.0f%%, Δ %+.0f%%)" % [old_pct, d_pct]
		else:
			value_text = ("%+.0f" % new_v) if key != "armor_value" else ("%0.0f" % new_v)
			if compare_item:
				value_text += " (сейчас %0.0f, Δ %+.0f)" % [old_v, delta]
		
		add_stat_line(label, value_text, color)

func _pretty_stat_name(key: String) -> String:
	match key:
		"armor_value": return "Броня"
		"max_health": return "Макс. здоровье"
		"max_hunger": return "Макс. голод"
		"max_thirst": return "Макс. жажда"
		"max_energy": return "Макс. энергия"
		"weight_reduction": return "Снижение веса"
		"extra_hotbar_slots": return "Слоты хотбара"
		"block_damage_bonus": return "Урон по блокам"
		"entity_damage": return "Урон по врагам"
		"hunger_decrease": return "Расход голода"
		"thirst_decrease": return "Расход жажды"
		"energy_decrease": return "Расход энергии"
		"harvest_speed": return "Скорость добычи"
		"crafting_speed": return "Скорость крафта"
		"movement_speed": return "Скорость передвижения"
		"attack_speed": return "Скорость атаки"
		_: return key

func _is_delta_better(key: String, delta: float, is_multiplier: bool) -> bool:
	if abs(delta) < 0.0001:
		return true
	
	# Lower is better for "decrease" rates (0.9 means -10% drain).
	if key in ["hunger_decrease","thirst_decrease","energy_decrease"]:
		return delta < 0.0
	
	# For most stats higher is better.
	return delta > 0.0

func _fit_background() -> void:
	if not is_instance_valid(background) or not is_instance_valid(content):
		return
	await get_tree().process_frame
	var size: Vector2 = content.get_combined_minimum_size()
	# Make the tooltip itself fit the content.
	self.custom_minimum_size = size
	self.size = size
	
	# Stretch background to full tooltip rect.
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.offset_left = 0.0
	background.offset_top = 0.0
	background.offset_right = 0.0
	background.offset_bottom = 0.0

func add_effect_line(effect: ItemEffect):
	var text = ""
	var color = Color.WHITE

	if effect.hunger_restore != 0:
		text += "Голод: " + ( "+" if effect.hunger_restore > 0 else "" ) + str(effect.hunger_restore) + " "
		color = Color.LIGHT_GREEN if effect.hunger_restore > 0 else Color.RED

	if effect.thirst_restore != 0:
		text += "Жажда: " + ( "+" if effect.thirst_restore > 0 else "" ) + str(effect.thirst_restore) + " "
		color = Color.DODGER_BLUE if effect.thirst_restore > 0 else Color.RED

	if effect.health_restore != 0:
		text += "Здоровье: " + ( "+" if effect.health_restore > 0 else "" ) + str(effect.health_restore) + " "
		color = Color.RED if effect.health_restore > 0 else Color.RED

	if effect.energy_restore != 0:
		text += "Энергия: " + ( "+" if effect.energy_restore > 0 else "" ) + str(effect.energy_restore) + " "
		color = Color(1.0, 0.85, 0.2) if effect.energy_restore > 0 else Color.RED

	if effect.effect_type == "OverTime" and effect.duration > 0.0:
		if effect.hunger_restore_per_second != 0.0:
			text += "Голод/с: " + str(effect.hunger_restore_per_second) + " "
		if effect.thirst_restore_per_second != 0.0:
			text += "Жажда/с: " + str(effect.thirst_restore_per_second) + " "
		if effect.health_restore_per_second != 0.0:
			text += "Здоровье/с: " + str(effect.health_restore_per_second) + " "
		if effect.energy_restore_per_second != 0.0:
			text += "Энергия/с: " + str(effect.energy_restore_per_second) + " "
		text += "Длит.: " + str(effect.duration) + "с "

	if effect.speed_multiplier != 1.0:
		var sign = "+" if effect.speed_multiplier > 1.0 else ""
		text += "Скорость: " + sign + str((effect.speed_multiplier - 1.0) * 100) + "% "

	if text != "":
		add_stat_line("Эффект", text.strip_edges(), color)

func add_stat_line(label_text: String, value_text: String, color: Color = Color.WHITE):
	var hbox = HBoxContainer.new()
	
	var label = Label.new()
	label.text = label_text + ": "
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", color)
	
	hbox.add_child(label)
	hbox.add_child(value)
	stats_container.add_child(hbox)

func hide_tooltip():
	hide()
