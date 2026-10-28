class_name FightHUD
extends Control
## Fighting-game HUD layer: 3-bar power meter, hit counter, damage-lag health trail and the current
## opponent's name + health bar. Sits inside the main HUD's root (640x360 virtual space).

const SEG_W: float = 44.0
const SEG_H: float = 5.0
const SEG_GAP: float = 2.0

var player: PlayerController
var _segments: Array[ColorRect] = []
var _seg_bgs: Array[ColorRect] = []
var _meter_label: Label
var _hits_label: Label
var _hits_word: Label
var _hits_alpha: float = 0.0
var _target_root: Control
var _target_name: Label
var _target_fill: ColorRect
var _target_trail: ColorRect
var _target: Node = null
var _special_label: Label
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var meter_root := Control.new()
	meter_root.position = Vector2(10, 25)
	meter_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(meter_root)
	for i in range(3):
		var bg := ColorRect.new()
		bg.color = Color(0.06, 0.07, 0.12, 0.85)
		bg.position = Vector2(i * (SEG_W + SEG_GAP), 0)
		bg.size = Vector2(SEG_W, SEG_H)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter_root.add_child(bg)
		var fill := ColorRect.new()
		fill.color = Color(0.3, 0.8, 1.0)
		fill.size = Vector2(0, SEG_H - 2)
		fill.position = Vector2(1, 1)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fill)
		_seg_bgs.append(bg)
		_segments.append(fill)
	_meter_label = _make_label(7, Color(0.75, 0.9, 1.0))
	_meter_label.position = Vector2(3 * (SEG_W + SEG_GAP) + 3, -3)
	meter_root.add_child(_meter_label)

	_hits_label = _make_label(26, Color(1.0, 0.92, 0.5))
	_hits_label.position = Vector2(12, 120)
	_hits_label.size = Vector2(90, 30)
	add_child(_hits_label)
	_hits_word = _make_label(9, Color(1.0, 0.75, 0.35))
	_hits_word.position = Vector2(14, 150)
	_hits_word.text = "HITS"
	add_child(_hits_word)

	_special_label = _make_label(18, Color(1.0, 0.95, 0.85))
	_special_label.set_anchors_preset(Control.PRESET_CENTER)
	_special_label.position = Vector2(-200, 40)
	_special_label.size = Vector2(400, 24)
	_special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_special_label.modulate.a = 0.0
	add_child(_special_label)

	_target_root = Control.new()
	_target_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_target_root.position = Vector2(-158, 36)
	_target_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_target_root)
	_target_name = _make_label(8, Color(1.0, 0.85, 0.8))
	_target_name.size = Vector2(148, 10)
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_target_root.add_child(_target_name)
	var tbg := ColorRect.new()
	tbg.color = Color(0.06, 0.05, 0.1, 0.85)
	tbg.position = Vector2(0, 12)
	tbg.size = Vector2(148, 6)
	tbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_root.add_child(tbg)
	_target_trail = ColorRect.new()
	_target_trail.color = Color(1.0, 0.9, 0.6, 0.9)
	_target_trail.position = Vector2(1, 1)
	_target_trail.size = Vector2(146, 4)
	_target_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tbg.add_child(_target_trail)
	_target_fill = ColorRect.new()
	_target_fill.color = Color(0.95, 0.25, 0.25)
	_target_fill.position = Vector2(1, 1)
	_target_fill.size = Vector2(146, 4)
	_target_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tbg.add_child(_target_fill)
	_target_root.visible = false


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func bind(p: PlayerController) -> void:
	player = p
	p.meter_changed.connect(_on_meter)
	p.hit_counter_changed.connect(_on_hits)
	p.special_performed.connect(_on_special)
	_on_meter(p.power_meter, PlayerController.METER_MAX)
	_on_hits(0)


func _on_meter(value: float, _max_value: float) -> void:
	for i in range(3):
		var f := clampf((value - i * 100.0) / 100.0, 0.0, 1.0)
		_segments[i].size.x = (SEG_W - 2) * f
		_segments[i].color = Color(1.0, 0.82, 0.3) if f >= 1.0 else Color(0.3, 0.8, 1.0)
	_meter_label.text = "x%d" % int(value / 100.0)


func _on_hits(n: int) -> void:
	if n >= 2:
		_hits_label.text = str(n)
		_hits_alpha = 1.0
		_hits_label.scale = Vector2(1.25, 1.25)
	elif n == 0:
		_hits_alpha = minf(_hits_alpha, 0.99)


func _on_special(_level: int, move_name: String) -> void:
	_special_label.text = move_name
	_special_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(_special_label, "modulate:a", 0.0, 0.4)


func _process(delta: float) -> void:
	_pulse += delta
	if player != null and is_instance_valid(player) and player.power_meter >= 300.0:
		for s in _segments:
			s.color = Color(1.0, 0.82 + 0.15 * sin(_pulse * 10.0), 0.3)
	_hits_label.scale = _hits_label.scale.lerp(Vector2.ONE, 1.0 - exp(-12.0 * delta))
	if _hits_alpha < 1.0:
		_hits_alpha = maxf(0.0, _hits_alpha - delta * 2.5)
	_hits_label.modulate.a = _hits_alpha
	_hits_word.modulate.a = _hits_alpha
	_update_target(delta)


func _update_target(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_target_root.visible = false
		return
	var t := _pick_target()
	if t != _target:
		_target = t
		if t != null:
			var hc := t.get("health_component") as HealthComponent
			_target_trail.size.x = 146.0 * (float(hc.current_health) / float(maxi(1, hc.max_health))) if hc else 146.0
	if _target == null:
		_target_root.visible = false
		return
	var hc := _target.get("health_component") as HealthComponent
	if hc == null:
		_target_root.visible = false
		return
	_target_root.visible = true
	var nm := String(_target.get("display_name"))
	if nm == "":
		nm = String(_target.get("sheet_key")).to_upper()
	_target_name.text = nm
	var ratio := clampf(float(hc.current_health) / float(maxi(1, hc.max_health)), 0.0, 1.0)
	_target_fill.size.x = 146.0 * ratio
	_target_trail.size.x = move_toward(_target_trail.size.x, _target_fill.size.x, 60.0 * delta)


func _pick_target() -> Node:
	var best: Node = null
	var best_d := 150.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as EnemyBase
		if n == null or not n.visible or n.is_defeated() or n.is_in_group("boss"):
			continue
		var d := n.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
