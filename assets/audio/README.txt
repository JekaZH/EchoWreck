Папка для звуков (.ogg / .wav). Назначай файлы в инспекторе Godot:

Магия (resources/combat/fireball_projectile.tres, ice_arrow_projectile.tres):
  cast_sound — ЛКМ, начало каста
  hit_explosion_sound — взрыв при попадании

Инструменты (resources/items/pickaxe_wood.tres, axe_wood.tres):
  tool_hit_sound — удар по камню / дереву

Оружие (resources/items/sword_wood.tres):
  weapon_hit_sound — удар мечом (кадр попадания)
  weapon_hit_volume_db — громкость

Шаги (resources/audio/default_player_footsteps.tres или Player → footstep_settings):
  step_clip — ресурс AudioStreamClipSettings (рекомендуется)
    Открой resources/audio/clips/walk_dust_step_clip.tres
    trim_start_sec — с какой секунды начать (убрать тишину в начале)
    trim_end_sec — сколько секунд отрезать с конца
  step_distance_m — интервал при ходьбе (больше = реже)
  run_step_distance_multiplier — при беге
  pickup_clip / pickup_volume_db — звук подбора (pickup.wav)
  surface_sounds — позже: разные clip по типу земли

Подбор:
  По умолчанию pickup_clip в default_player_footsteps.tres
  У предмета (ItemData) — pickup_sound перекрывает дефолт

Обрезка в Import:
  Выбери .wav → Import → Edit → Trim / loop_begin / loop_end (меняет сам файл)
  Для тонкой настройки без переимпорта — AudioStreamClipSettings в .tres
