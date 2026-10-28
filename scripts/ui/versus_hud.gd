class_name VersusHUD
extends Control
## Fighting-game HUD for versus matches: mirrored portrait + name + level + class badge (with the class
## advantage arrow) + health (with damage trail) + power meter for each side, buff/debuff icons with
## timers, active boosts, team roster pips (KO'd fighters greyed), round timer, hit counters and banners.

const BAR_W: float = 200.0

var _sides: Array = [{}, {}]
var timer_label: Label
var banner: Label
var banner_sub: Label
var mode_label: Label


var _w: float = 640.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# explicit positions from the real viewport width (the 640x360 base view expands on wide phones)
	_w = maxf(640.0, get_viewport_rect().size.x)
	var h := maxf(360.0, get_viewport_rect().size.y)
	for i in range(2):
		_sides[i] = _build_side(i)
	timer_label = _label(22, Color(1, 1, 1))
	timer_label.position = Vector2(_w * 0.5 - 30, 6)
	timer_label.size = Vector2(60, 26)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(timer_label)
	mode_label = _label(7, Color(0.8, 0.85, 1.0))
	mode_label.position = Vector2(_w * 0.5 - 60, 32)
	mode_label.size = Vector2(120, 10)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(mode_label)
	banner = _label(30, Color(1, 0.95, 0.85))
	banner.position = Vector2(_w * 0.5 - 260, h * 0.5 - 60)
	banner.size = Vector2(520, 40)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	add_child(banner)
	banner_sub = _label(11, Color(1, 0.8, 0.45))
	banner_sub.position = Vector2(_w * 0.5 - 260, h * 0.5 - 18)
	banner_sub.size = Vector2(520, 16)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.modulate.a = 0.0
	add_child(banner_sub)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _build_side(i: int) -> Dictionary:
	var right := i == 1
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right:
		root.position = Vector2(_w - 8 - 48 - BAR_W, 6)
	else:
		root.position = Vector2(8, 6)
	add_child(root)
	var d := {"root": root}
	var frame := _rect(root, Vector2(BAR_W + 6 if right else 0, 0), Vector2(42, 42), Color(0.05, 0.05, 0.1, 0.9))
	var por := TextureRect.new()
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	por.position = Vector2(1, 1)
	por.size = Vector2(40, 40)
	por.flip_h = right
	por.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(por)
	d["portrait"] = por
	var bx := 0.0 if right else 46.0
	var name_l := _label(9, Color(1, 0.92, 0.75))
	name_l.position = Vector2(bx, -2)
	name_l.size = Vector2(BAR_W, 12)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(name_l)
	d["name"] = name_l
	var bg := _rect(root, Vector2(bx, 12), Vector2(BAR_W, 10), Color(0.06, 0.05, 0.1, 0.92))
	d["trail"] = _rect(bg, Vector2(1, 1), Vector2(BAR_W - 2, 8), Color(1.0, 0.9, 0.55))
	d["fill"] = _rect(bg, Vector2(1, 1), Vector2(BAR_W - 2, 8), Color(0.3, 0.9, 0.4))
	d["bg"] = bg
	d["right"] = right
	var segs: Array = []
	for s in range(3):
		var sb := _rect(root, Vector2(bx + (BAR_W - 3 * 46.0 if right else 0.0) + s * 46.0, 25), Vector2(44, 4), Color(0.06, 0.07, 0.12, 0.9))
		segs.append(_rect(sb, Vector2(1, 1), Vector2(0, 2), Color(0.3, 0.8, 1.0)))
	d["segs"] = segs
	var pips: Array = []
	for s in range(3):
		var pr := TextureRect.new()
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pr.size = Vector2(14, 14)
		pr.position = Vector2(bx + (BAR_W - 14 - s * 16 if right else s * 16.0), 31)
		pr.flip_h = right
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(pr)
		pips.append(pr)
	d["pips"] = pips
	var hits := _label(22, Color(1, 0.92, 0.5))
	hits.position = Vector2(bx + (BAR_W - 60 if right else 0.0), 110)
	hits.size = Vector2(60, 26)
	hits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	hits.modulate.a = 0.0
	root.add_child(hits)
	d["hits"] = hits
	var cls := _label(7, Color(1, 1, 1))
	cls.position = Vector2(bx, 2)
	cls.size = Vector2(BAR_W, 10)
	cls.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if right else HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(cls)
	d["class"] = cls
	var fx_row := HBoxContainer.new()
	fx_row.add_theme_constant_override("separation", 2)
	fx_row.position = Vector2(bx, 47)
	fx_row.size = Vector2(BAR_W, 10)
	fx_row.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
	fx_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fx_row)
	d["fx_row"] = fx_row
	d["fx_chips"] = {}
	var bl := _label(6, Color(0.85, 0.9, 1.0))
	bl.position = Vector2(bx, 59)
	bl.size = Vector2(BAR_W, 9)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(bl)
	d["boost_label"] = bl
	return d


## Class badge; adv = +1 (advantage, green arrow up) / -1 (disadvantage, red arrow down) / 0.
func set_class(side: int, key: String, adv: int) -> void:
	var l: Label = _sides[side]["class"]
	var c := SpiderRoster.class_of(key)
	var arrow := " \u25B2" if adv > 0 else (" \u25BC" if adv < 0 else "")
	l.text = (arrow + "  " + c) if bool(_sides[side]["right"]) else (c + arrow)
	l.add_theme_color_override("font_color", SpiderRoster.CLASS_COLORS.get(c, Color.WHITE) if adv == 0 else (Color(0.4, 1.0, 0.45) if adv > 0 else Color(1.0, 0.4, 0.35)))


## Active boosts and synergies for a side, as one compact line.
func set_boosts(side: int, boost_keys: Array, synergies: Array) -> void:
	var parts: Array = []
	for b in boost_keys:
		parts.append(String(GameState.BOOSTS[String(b)][0]).replace(" BOOST", "+"))
	for s in synergies:
		parts.append(String(s[0]))
	(_sides[side]["boost_label"] as Label).text = "  ".join(parts)


## team_keys: roster keys; alive: Array[bool]
func set_team(side: int, team_keys: Array, alive: Array) -> void:
	var d: Dictionary = _sides[side]
	var pips: Array = d["pips"]
	for s in range(3):
		var pr: TextureRect = pips[s]
		pr.visible = s < team_keys.size() and team_keys.size() > 1
		if pr.visible:
			pr.texture = load(SpiderRoster.portrait_path(String(team_keys[s])))
			pr.modulate = Color(1, 1, 1) if bool(alive[s]) else Color(0.25, 0.2, 0.2, 0.8)


func bind_fighter(side: int, f: PlayerController, level: int = 1) -> void:
	var d: Dictionary = _sides[side]
	var info := SpiderRoster.info(f.character_key)
	(d["portrait"] as TextureRect).texture = load(String(info["portrait"]))
	(d["name"] as Label).text = ("LV%d  %s" if bool(d["right"]) else "%s  LV%d") % ([level, String(info["name"])] if bool(d["right"]) else [String(info["name"]), level])
	for c in (d["fx_row"] as HBoxContainer).get_children():
		c.queue_free()
	d["fx_chips"] = {}
	d["fighter"] = f
	f.health_component.health_changed.connect(func(c: int, m: int) -> void: _set_hp(side, c, m))
	f.meter_changed.connect(func(v: float, _m: float) -> void: _set_meter(side, v))
	f.hit_counter_changed.connect(func(n: int) -> void: _set_hits(side, n))
	_set_hp(side, f.health_component.current_health, f.health_component.max_health)
	(d["trail"] as ColorRect).size.x = (d["fill"] as ColorRect).size.x
	_set_meter(side, f.power_meter)


func _bar_rect(d: Dictionary, frac: float, node: ColorRect) -> void:
	var w := (BAR_W - 2) * clampf(frac, 0.0, 1.0)
	node.size.x = w
	node.position.x = 1.0 + ((BAR_W - 2) - w if bool(d["right"]) else 0.0)


func _set_hp(side: int, c: int, m: int) -> void:
	var d: Dictionary = _sides[side]
	var r := clampf(float(c) / float(maxi(1, m)), 0.0, 1.0)
	_bar_rect(d, r, d["fill"])
	(d["fill"] as ColorRect).color = Color(0.3, 0.9, 0.4) if r > 0.5 else (Color(1.0, 0.8, 0.25) if r > 0.25 else Color(0.95, 0.25, 0.25))
	d["hp_ratio"] = r


func _set_meter(side: int, v: float) -> void:
	var segs: Array = _sides[side]["segs"]
	for i in range(3):
		var f := clampf((v - i * 100.0) / 100.0, 0.0, 1.0)
		var s: ColorRect = segs[i]
		s.size.x = 42.0 * f
		s.color = Color(1.0, 0.82, 0.3) if f >= 1.0 else Color(0.3, 0.8, 1.0)


func _set_hits(side: int, n: int) -> void:
	var l: Label = _sides[side]["hits"]
	if n >= 2:
		l.text = "%d HITS" % n
		l.modulate.a = 1.0


func set_time(t: float) -> void:
	timer_label.text = str(int(ceil(maxf(0.0, t))))
	timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if t < 10.0 else Color(1, 1, 1))


func show_banner(title: String, sub: String = "", hold: float = 1.3) -> void:
	banner.text = title
	banner_sub.text = sub
	banner.modulate.a = 1.0
	banner_sub.modulate.a = 1.0
	banner.scale = Vector2(1.4, 1.4)
	banner.pivot_offset = banner.size * 0.5
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(banner_sub, "modulate:a", 0.0, 0.3)


func _update_effects(d: Dictionary) -> void:
	var fo: Variant = d.get("fighter")
	if not is_instance_valid(fo) or (fo as PlayerController).effects == null:
		return
	var fx := (fo as PlayerController).effects
	var chips: Dictionary = d["fx_chips"]
	for k in chips.keys():
		if not fx.active.has(k):
			(chips[k] as Control).queue_free()
			chips.erase(k)
	for k in fx.active:
		var e: Dictionary = fx.active[k]
		var chip: Control = chips.get(k)
		if chip == null:
			var def: Dictionary = FightEffects.DEFS[k]
			chip = ColorRect.new()
			(chip as ColorRect).color = Color(0.03, 0.03, 0.08, 0.85)
			chip.custom_minimum_size = Vector2(26, 10)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bar := ColorRect.new()
			bar.name = "Bar"
			bar.color = def["color"]
			bar.position = Vector2(0, 8)
			bar.size = Vector2(26, 2)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(bar)
			var t := _label(6, def["color"])
			t.name = "Tag"
			t.add_theme_constant_override("outline_size", 2)
			t.position = Vector2(0, -2)
			t.size = Vector2(26, 9)
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip.add_child(t)
			(d["fx_row"] as HBoxContainer).add_child(chip)
			chips[k] = chip
		var tag := String(FightEffects.DEFS[k]["tag"])
		(chip.get_node("Tag") as Label).text = tag + ("%d" % int(e["stacks"]) if int(e["stacks"]) > 1 else "")
		(chip.get_node("Bar") as ColorRect).size.x = 26.0 * clampf(float(e["t"]) / maxf(0.01, float(e["dur"])), 0.0, 1.0)


func _process(delta: float) -> void:
	for d in _sides:
		if d.has("fx_row"):
			_update_effects(d)
		if d.has("trail"):
			var tr: ColorRect = d["trail"]
			var target := (BAR_W - 2) * float(d.get("hp_ratio", 1.0))
			var w := move_toward(tr.size.x, target, 70.0 * delta) if tr.size.x > target else target
			tr.size.x = w
			tr.position.x = 1.0 + ((BAR_W - 2) - w if bool(d["right"]) else 0.0)
		if d.has("hits"):
			var l: Label = d["hits"]
			var fo: Variant = d.get("fighter")
			if l.modulate.a > 0.0 and (not is_instance_valid(fo) or (fo as PlayerController).hit_counter < 2):
				l.modulate.a = maxf(0.0, l.modulate.a - delta * 2.0)
