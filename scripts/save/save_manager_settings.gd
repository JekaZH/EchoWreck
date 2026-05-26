@tool
class_name SaveManagerSettings
extends Resource
## Настройки автосохранения (редактор: `resources/save/save_manager_settings.tres`).

@export_group("Автосохранение")
@export var autosave_enabled: bool = true
@export var autosave_on_level_transition: bool = true
@export_range(30.0, 3600.0, 5.0) var autosave_interval_seconds: float = 300.0

@export_group("Несохранённые изменения")
@export var warn_unsaved_on_exit_to_menu: bool = true
