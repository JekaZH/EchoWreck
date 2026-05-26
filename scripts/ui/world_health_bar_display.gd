class_name WorldHealthBarDisplay
extends Node3D
## Полоска HP в мире. Текст — Label3D (billboard, как подбор), полоска — Sprite3D.

const VIEWPORT_SIZE := Vector2i(152, 52)
const PIXEL_SIZE := 0.006

@export var visibility_mode: HealthBarVisibilityMode.Mode = HealthBarVisibilityMode.Mode.ON_DAMAGE
@export var hide_after_seconds: float = 2.5
@export var bar_width_meters: float = 1.15
@export var label_height_offset: float = 0.46
@export var fill_color: Color = Color(0.82, 0.14, 0.12, 1.0)
@export var background_color: Color = Color(0.06, 0.06, 0.08, 0.96)
@export var border_color: Color = Color(0.18, 0.18, 0.2, 1.0)
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.45)
@export var text_color: Color = Color(1.0, 0.98, 0.95, 1.0)
@export var text_outline_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var text_outline_size: int = 12
@export var text_font_size: int = 48

const _FILL_PAD_LEFT := 7.0
const _FILL_PAD_RIGHT := 7.0
const _FILL_PAD_V := 7.0

var _health: HealthComponent
var _highlighted: bool = false
var _hide_timer: float = 0.0

@onready var _viewport: SubViewport = $SubViewport
@onready var _sprite: Sprite3D = $BarSprite
@onready var _label_3d: Label3D = $HealthLabel3D
@onready var _shadow: ColorRect = $SubViewport/BarRoot/Shadow
@onready var _border: ColorRect = $SubViewport/BarRoot/Border
@onready var _background: ColorRect = $SubViewport/BarRoot/Background
@onready var _fill: ColorRect = $SubViewport/BarRoot/Fill


func _ready() -> void:
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_setup_bar_sprite()
	_apply_label_3d()
	_apply_bar_colors()
	_set_bar_visible(false)
	if _health != null:
		_on_health_changed(_health.current_health, _health.max_health)
		_refresh_visibility()


func _process(delta: float) -> void:
	if _hide_timer <= 0.0:
		return
	_hide_timer = maxf(_hide_timer - delta, 0.0)
	if _hide_timer <= 0.0:
		_refresh_visibility()


func bind_to(health: HealthComponent) -> void:
	if _health != null and is_instance_valid(_health):
		if _health.health_changed.is_connected(_on_health_changed):
			_health.health_changed.disconnect(_on_health_changed)
		if _health.damaged.is_connected(_on_damaged):
			_health.damaged.disconnect(_on_damaged)
	_health = health
	if _health == null:
		return
	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(_on_damaged)
	if is_node_ready():
		_on_health_changed(_health.current_health, _health.max_health)
		_refresh_visibility()
		_refresh_viewport_texture()


func set_highlighted(enabled: bool) -> void:
	_highlighted = enabled
	_refresh_visibility()


func _on_health_changed(current: float, maximum: float) -> void:
	_update_fill(current, maximum)
	_update_label(current, maximum)
	_refresh_viewport_texture()


func _on_damaged(_amount: float, _source: Node) -> void:
	if visibility_mode == HealthBarVisibilityMode.Mode.ON_DAMAGE:
		_hide_timer = hide_after_seconds
	_set_bar_visible(true)


func _setup_bar_sprite() -> void:
	_sprite.texture = _viewport.get_texture()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var uniform_scale := bar_width_meters / (float(VIEWPORT_SIZE.x) * PIXEL_SIZE)
	_sprite.scale = Vector3(uniform_scale, uniform_scale, 1.0)


func _apply_label_3d() -> void:
	if _label_3d == null:
		return
	_label_3d.position = Vector3(0.0, label_height_offset, 0.0)
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_3d.font_size = text_font_size
	_label_3d.outline_size = text_outline_size
	_label_3d.modulate = text_color
	_label_3d.outline_modulate = text_outline_color
	_label_3d.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER


func _update_fill(current: float, maximum: float) -> void:
	if _fill == null:
		return
	var ratio := 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	_fill.anchor_right = ratio
	_fill.offset_left = _FILL_PAD_LEFT
	_fill.offset_top = _FILL_PAD_V
	_fill.offset_bottom = -_FILL_PAD_V
	_fill.offset_right = -_FILL_PAD_RIGHT


func _update_label(current: float, maximum: float) -> void:
	if _label_3d == null:
		return
	var cur_i := maxi(0, int(ceil(current)))
	var max_i := maxi(1, int(ceil(maximum)))
	_label_3d.text = "%d/%d" % [cur_i, max_i]


func _apply_bar_colors() -> void:
	if _shadow:
		_shadow.color = shadow_color
	if _border:
		_border.color = border_color
	if _background:
		_background.color = background_color
	if _fill:
		_fill.color = fill_color


func _refresh_viewport_texture() -> void:
	if _viewport == null:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _refresh_visibility() -> void:
	match visibility_mode:
		HealthBarVisibilityMode.Mode.NEVER:
			_set_bar_visible(false)
		HealthBarVisibilityMode.Mode.ALWAYS:
			_set_bar_visible(_health != null and _health.is_alive())
		HealthBarVisibilityMode.Mode.WHEN_HIGHLIGHTED:
			_set_bar_visible(_highlighted and _health != null and _health.is_alive())
		HealthBarVisibilityMode.Mode.ON_DAMAGE:
			var show := _hide_timer > 0.0 or _highlighted
			_set_bar_visible(show and _health != null and _health.is_alive())


func _set_bar_visible(visible: bool) -> void:
	if _sprite:
		_sprite.visible = visible
	if _label_3d:
		_label_3d.visible = visible
	if visible:
		_refresh_viewport_texture()


static func estimate_top_offset(root: Node3D, padding: float = 0.4) -> float:
	var top_y := 0.0
	for mesh in _collect_mesh_instances(root):
		var aabb := mesh.get_aabb()
		var local_top := mesh.position.y + aabb.position.y + aabb.size.y
		top_y = maxf(top_y, local_top)
	return top_y + padding


static func _collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			result.append(mesh)
	for child in node.get_children():
		result.append_array(_collect_mesh_instances(child))
	return result
