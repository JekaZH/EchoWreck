class_name ItemTooltip
extends Control

@onready var name_label: Label = $Background/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var type_label: Label = $Background/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/TypeLabel
@onready var icon_rect: TextureRect = $Background/MarginContainer/VBoxContainer/HBoxContainer/Icon
@onready var description_label: Label = $Background/MarginContainer/VBoxContainer/DescriptionLabel
@onready var stats_container: VBoxContainer = $Background/MarginContainer/VBoxContainer/StatsContainer

var is_ready := false

func _ready():
	is_ready = true

func show_tooltip(item: ItemData):
	if not item:
		hide()
		return

	name_label.text = item.display_name
	name_label.add_theme_color_override("font_color", item.get_rarity_color())
	
	type_label.text = item.category
	icon_rect.texture = item.icon
	description_label.text = item.description if item.description else "Нет описания"

	# Очищаем старые статы
	for child in stats_container.get_children():
		child.queue_free()

	if item.tool_type != "":
		add_stat_line("Инструмент", item.tool_type.capitalize(), Color.LIGHT_BLUE)
	
	if item.is_weapon and item.damage > 0:
		add_stat_line("Урон", "+" + str(item.damage), Color.ORANGE)	

	for effect in item.effects:
		add_effect_line(effect)

	show()

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
		color = Color.RED if effect.health_restore > 0 else Color.RED  # здоровье всегда красный

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
