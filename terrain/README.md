# Terrain3D — ручная работа

Автогенерация **выключена**. Создайте мир в редакторе:

1. Откройте `scenes/world/terrain/world_terrain.tscn`.
2. Выберите `WorldTerrain` → панель **Terrain3D**.
3. Добавьте **4 региона** (2×2) вокруг (0,0), каждый **128×128 м**:
   - индексы: `(-1,-1)`, `(0,-1)`, `(-1,0)`, `(0,0)`
4. Sculpt / Paint текстуры (трава, камень).
5. **Meshes → Grass** — рисуйте траву кистью Instancer (не generated mesh).
6. **Terrain3D → Save to Directory** → `res://terrain` (или включите `save_generated_to_disk` и сохраните сцену после лепки).

В `world_terrain_assets.tres` только **Grass_Common_Short** — без серого generated mesh.

Процедурный превью (если нужен): `Editor Regenerate Now` на `WorldTerrain`.

**При запуске игры без сохранённых регионов** включён `runtime_fallback_if_empty`: один раз создаётся процедурный terrain и сохраняется в `res://terrain`. Отключите, если нужен строго пустой мир до ручной лепки.
