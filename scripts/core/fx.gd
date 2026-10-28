extends Node
## Autoload "Fx": hit-stop, camera shake, screen flash and pooled one-shot particle bursts.

var _shake_strength: float = 0.0
var _shake_time: float = 0.0
var _shake_total: float = 0.0
var _base_offsets: Dictionary = {}       # camera instance id -> base offset
var _hitstop_active: bool = false
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
## Tests and the movie-capture tool can disable hit-stop to keep frame timing deterministic.
var hitstop_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 50
	add_child(_flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_layer.add_child(_flash_rect)


## Briefly freezes gameplay time for impact weight. Real-time timer so it always recovers.
func hitstop(duration: float = 0.05, time_scale: float = 0.05) -> void:
	if not hitstop_enabled or _hitstop_active or get_tree().paused:
		return
	_hitstop_active = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func shake(strength: float = 3.0, duration: float = 0.15) -> void:
	if strength >= _shake_strength or _shake_time <= 0.0:
		_shake_strength = strength
		_shake_total = duration
		_shake_time = duration


func flash(color: Color = Color(1, 1, 1, 0.6), duration: float = 0.18) -> void:
	_flash_rect.color = color
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var id := cam.get_instance_id()
	if not _base_offsets.has(id):
		_base_offsets[id] = cam.offset
	var base: Vector2 = _base_offsets[id]
	if _shake_time > 0.0:
		_shake_time -= delta
		var k := clampf(_shake_time / maxf(0.001, _shake_total), 0.0, 1.0)
		cam.offset = base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength * k
	else:
		_shake_strength = 0.0
		cam.offset = base


## Spawns a self-freeing particle burst at a world position under `parent`.
func burst(parent: Node, pos: Vector2, color: Color, amount: int = 12, speed: float = 90.0, gravity: float = 200.0, life: float = 0.35) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.spread = 180.0
	p.gravity = Vector2(0, gravity)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = color
	p.global_position = pos
	p.z_index = 20
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)


## Floating damage / callout text.
func popup_text(parent: Node, pos: Vector2, text: String, color: Color = Color(1, 0.9, 0.3), size: int = 10) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos + Vector2(-30, -10)
	l.size = Vector2(60, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 30
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 18.0, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)
