class_name MagicVfxTextures
extends RefCounted
## Загрузка T_VFX_basic1 / T_VFX_Noi55. Без файлов — простые процедурные заглушки.

const BASIC_PATHS: PackedStringArray = [
	"res://assets/vfx/magic_projectiles/T_VFX_basic1.png",
	"res://assets/vfx/magic_projectiles/T_VFX_basic1.PNG",
]
const NOISE_PATHS: PackedStringArray = [
	"res://assets/vfx/magic_projectiles/T_VFX_Noi55.png",
	"res://assets/vfx/magic_projectiles/T_VFX_No55.png",
]

const FALLBACK_SOFT_GLOW_SIZE_PX := 128
const FALLBACK_NOISE_SIZE_PX := 256
const SOFT_GLOW_RADIUS_RATIO := 0.42
const SOFT_GLOW_EDGE_POWER := 1.8

static var _basic: Texture2D
static var _noise: Texture2D


static func get_basic() -> Texture2D:
	if _basic == null:
		_basic = _load_first(BASIC_PATHS, _make_soft_glow_fallback)
	return _basic


static func get_noise() -> Texture2D:
	if _noise == null:
		_noise = _load_first(NOISE_PATHS, _make_noise_fallback)
	return _noise


static func _load_first(paths: PackedStringArray, fallback: Callable) -> Texture2D:
	for path in paths:
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				return tex
	return fallback.call() as Texture2D


static func _make_soft_glow_fallback() -> Texture2D:
	var size := FALLBACK_SOFT_GLOW_SIZE_PX
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := float(size) * SOFT_GLOW_RADIUS_RATIO
	for y in size:
		for x in size:
			var pixel := Vector2(x, y)
			var distance_ratio := pixel.distance_to(center) / radius
			var alpha := clampf(1.0 - distance_ratio * distance_ratio, 0.0, 1.0)
			alpha = pow(alpha, SOFT_GLOW_EDGE_POWER)
			image.set_pixel(x, y, Color(1.0, 0.92, 0.75, alpha))
	return ImageTexture.create_from_image(image)


static func _make_noise_fallback() -> Texture2D:
	var size := FALLBACK_NOISE_SIZE_PX
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var uv := Vector2(x, y) / float(size)
			var brightness := _procedural_noise_01(uv)
			image.set_pixel(x, y, Color(brightness, brightness * 0.85, brightness * 0.7, 1.0))
	return ImageTexture.create_from_image(image)


## Псевдослучайный шум 0..1 из синусов (только для заглушки, пока нет T_VFX_Noi55).
static func _procedural_noise_01(uv: Vector2) -> float:
	var wave_a := sin(uv.x * TAU * 2.0) * sin(uv.y * TAU * 1.7)
	var wave_b := sin((uv.x + uv.y) * TAU * 4.3) * 0.5
	var combined := wave_a + wave_b
	return clampf((combined + 1.5) / 3.0, 0.0, 1.0)
