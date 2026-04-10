class_name PlayerStatsUI
extends Control

# Правильные пути под твою структуру (HBoxContainer вместо HealthHBox)
@onready var health_bar: ProgressBar = $StatsContainer/HBoxContainer/HealthBar
@onready var health_label: Label = $StatsContainer/HBoxContainer/HealthLabel

@onready var hunger_bar: ProgressBar = $StatsContainer/HBoxContainer2/HungerBar
@onready var hunger_label: Label = $StatsContainer/HBoxContainer2/HungerLabel

@onready var thirst_bar: ProgressBar = $StatsContainer/HBoxContainer3/ThirstBar
@onready var thirst_label: Label = $StatsContainer/HBoxContainer3/ThirstLabel

@onready var energy_bar: ProgressBar = $StatsContainer/HBoxContainer4/EnergyBar
@onready var energy_label: Label = $StatsContainer/HBoxContainer4/EnergyLabel

var stats: PlayerStats = null

func setup(player_stats: PlayerStats):
	stats = player_stats
	if not stats:
		print("PlayerStatsUI: stats is null")
		return
	update_all()

func update_all():
	if not stats:
		return

	# Здоровье
	if health_bar:
		health_bar.max_value = stats.max_health
		health_bar.value = stats.health
	if health_label:
		health_label.text = str(int(stats.health)) + "/" + str(int(stats.max_health))

	# Голод
	if hunger_bar:
		hunger_bar.max_value = stats.max_hunger
		hunger_bar.value = stats.hunger
	if hunger_label:
		hunger_label.text = str(int(stats.hunger)) + "/" + str(int(stats.max_hunger))

	# Жажда
	if thirst_bar:
		thirst_bar.max_value = stats.max_thirst
		thirst_bar.value = stats.thirst
	if thirst_label:
		thirst_label.text = str(int(stats.thirst)) + "/" + str(int(stats.max_thirst))

	# Энергия
	if energy_bar:
		energy_bar.max_value = stats.max_energy
		energy_bar.value = stats.energy
	if energy_label:
		energy_label.text = str(int(stats.energy)) + "/" + str(int(stats.max_energy))

func _process(_delta):
	update_all()
