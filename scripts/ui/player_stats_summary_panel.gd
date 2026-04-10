class_name PlayerStatsSummaryPanel
extends Control

@onready var title_label: Label = $Background/Margin/VBox/Title
@onready var content: RichTextLabel = $Background/Margin/VBox/Content

var _equipment: PlayerEquipment = null
var _stats_comp: PlayerStatsComponent = null

@export var screen_margin: Vector2 = Vector2(24, 24)
@export var y_offset: float = -80.0

const ADDITIVE_KEYS: Array[String] = [
	"max_health",
	"max_hunger",
	"max_thirst",
	"max_energy",
	"armor_value",
	"block_damage_bonus",
	"entity_damage",
	"weight_reduction",
	"extra_hotbar_slots",
]

const MULTIPLIER_KEYS: Array[String] = [
	"hunger_decrease",
	"thirst_decrease",
	"energy_decrease",
	"harvest_speed",
	"crafting_speed",
	"movement_speed",
	"attack_speed",
]

func setup(equipment: PlayerEquipment, stats_component: PlayerStatsComponent) -> void:
	_equipment = equipment
	_stats_comp = stats_component
	if _equipment and _equipment.has_signal("equipment_changed"):
		if not _equipment.equipment_changed.is_connected(_on_equipment_changed):
			_equipment.equipment_changed.connect(_on_equipment_changed)
	_refresh()

func place_next_to(target: Control, side: String = "RIGHT") -> void:
	if not target or not is_instance_valid(target):
		return
	call_deferred("_place_next_to_deferred", target, side)

func _place_next_to_deferred(target: Control, side: String) -> void:
	await get_tree().process_frame
	var bg := get_node_or_null("Background") as Control
	if not bg or not is_instance_valid(target):
		return

	var size: Vector2 = bg.get_combined_minimum_size()
	size.x = max(size.x, 1.0)
	size.y = max(size.y, 1.0)

	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 0.0
	bg.anchor_bottom = 0.0
	bg.offset_left = 0.0
	bg.offset_top = 0.0
	bg.offset_right = size.x
	bg.offset_bottom = size.y

	custom_minimum_size = size
	self.size = size

	var vp: Vector2 = get_viewport_rect().size
	var margin := screen_margin
	margin.x = max(0.0, margin.x)
	margin.y = max(0.0, margin.y)

	var desired_pos := position
	if side == "RIGHT":
		desired_pos = Vector2(target.position.x + target.size.x + margin.x, target.position.y)
	elif side == "LEFT":
		desired_pos = Vector2(target.position.x - size.x - margin.x, target.position.y)
	elif side == "TOP":
		desired_pos = Vector2(target.position.x, target.position.y - size.y - margin.y)
	elif side == "BOTTOM":
		desired_pos = Vector2(target.position.x, target.position.y + target.size.y + margin.y)

	desired_pos.y = target.position.y + y_offset

	var max_x := vp.x - size.x - margin.x
	var max_y := vp.y - size.y - margin.y
	desired_pos.x = clampf(desired_pos.x, margin.x, max_x)
	desired_pos.y = clampf(desired_pos.y, margin.y, max_y)
	position = desired_pos

func _process(_delta: float) -> void:
	# Keep it live while inventory is open (health/hunger drain changes too).
	_refresh()

func _on_equipment_changed(_slot: String, _item: ItemData) -> void:
	_refresh()

func _refresh() -> void:
	if not content:
		return

	var stats: PlayerStats = _stats_comp.stats if _stats_comp else null
	var custom: Dictionary = stats.custom_stats if stats else {}

	var additive_totals := _compute_additive_totals()
	var multiplier_totals := _compute_multiplier_totals()

	var lines: Array[String] = []
	lines.append("[b]Текущие параметры[/b]")
	if stats:
		lines.append("Здоровье: %d/%d" % [int(stats.health), int(stats.max_health)])
		lines.append("Голод: %d/%d" % [int(stats.hunger), int(stats.max_hunger)])
		lines.append("Жажда: %d/%d" % [int(stats.thirst), int(stats.max_thirst)])
		lines.append("Энергия: %d/%d" % [int(stats.energy), int(stats.max_energy)])
	else:
		lines.append("[color=#aaaaaa]Статы игрока не найдены[/color]")

	lines.append("")
	lines.append("[b]Бонусы (плоские)[/b]")
	lines.append(_as_two_column_table_additives(additive_totals))

	lines.append("")
	lines.append("[b]Бонусы (множители)[/b]")
	lines.append(_as_two_column_table_multipliers(multiplier_totals))

	lines.append("")
	lines.append("[b]Прочие параметры[/b]")
	if custom and custom.size() > 0:
		# Show unknown keys too (future-proof)
		for ck in custom.keys():
			lines.append("• %s: %s" % [_pretty_key(str(ck)), str(custom[ck])])
	else:
		lines.append("[color=#aaaaaa]— пусто[/color]")

	content.bbcode_enabled = true
	content.text = "\n".join(lines)

func _as_two_column_table_additives(additive_totals: Dictionary) -> String:
	var cells: Array[String] = []
	for k in ADDITIVE_KEYS:
		var v: float = float(additive_totals.get(k, 0.0))
		var has_any: bool = absf(v) > 0.0001
		cells.append(_fmt_additive(k, v, has_any))
	return _two_col(cells)

func _as_two_column_table_multipliers(multiplier_totals: Dictionary) -> String:
	var cells: Array[String] = []
	for k in MULTIPLIER_KEYS:
		var mv: float = float(multiplier_totals.get(k, 1.0))
		var has_any: bool = absf(mv - 1.0) > 0.0001
		cells.append(_fmt_multiplier(k, mv, has_any))
	return _two_col(cells)

func _two_col(items: Array[String]) -> String:
	if items.is_empty():
		return ""
	var out: Array[String] = []
	out.append("[table=2]")
	for i in range(items.size()):
		out.append("[cell]%s[/cell]" % items[i])
	out.append("[/table]")
	return "\n".join(out)

func _compute_additive_totals() -> Dictionary:
	var totals: Dictionary = {}
	if not _equipment:
		return totals
	for it in _equipment.equipped_items.values():
		if not it:
			continue
		for k in it.stat_additives.keys():
			var key := str(k)
			totals[key] = float(totals.get(key, 0.0)) + float(it.stat_additives[k])
		# armor_value / weight_reduction are dedicated fields on ItemData too.
		if it.armor_value != 0.0:
			totals["armor_value"] = float(totals.get("armor_value", 0.0)) + float(it.armor_value)
		if it.weight_reduction != 0.0:
			totals["weight_reduction"] = float(totals.get("weight_reduction", 0.0)) + float(it.weight_reduction)
	return totals

func _compute_multiplier_totals() -> Dictionary:
	var totals: Dictionary = {}
	if not _equipment:
		return totals
	for it in _equipment.equipped_items.values():
		if not it:
			continue
		for k in it.stat_multipliers.keys():
			var key := str(k)
			var v: float = float(it.stat_multipliers[k])
			if not totals.has(key):
				totals[key] = 1.0
			totals[key] = float(totals[key]) * v
	return totals

func _fmt_additive(key: String, value: float, enabled: bool) -> String:
	var sign := "+" if value >= 0.0 else ""
	var color := "#e6e6e6" if enabled else "#777777"
	return "[color=%s]%s: %s%s[/color]" % [color, _pretty_key(key), sign, str(int(value)) if absf(value - float(int(value))) < 0.0001 else str(value)]

func _fmt_multiplier(key: String, mult: float, enabled: bool) -> String:
	var color := "#e6e6e6" if enabled else "#777777"
	var pct: float = (mult - 1.0) * 100.0
	var sign := "+" if pct >= 0.0 else ""
	return "[color=%s]%s: x%.3f  (%s%.1f%%)[/color]" % [color, _pretty_key(key), mult, sign, pct]

func _pretty_key(k: String) -> String:
	match k:
		"max_health": return "Макс. здоровье"
		"max_hunger": return "Макс. голод"
		"max_thirst": return "Макс. жажда"
		"max_energy": return "Макс. энергия"
		"armor_value": return "Броня"
		"weight_reduction": return "Снижение веса"
		"extra_hotbar_slots": return "Слоты хотбара"
		"block_damage_bonus": return "Урон по блокам"
		"entity_damage": return "Урон по существам"
		"hunger_decrease": return "Расход голода"
		"thirst_decrease": return "Расход жажды"
		"energy_decrease": return "Расход энергии"
		"harvest_speed": return "Скорость добычи"
		"crafting_speed": return "Скорость крафта"
		"movement_speed": return "Скорость передвижения"
		"attack_speed": return "Скорость атаки"
		_: return k.capitalize().replace("_", " ")
