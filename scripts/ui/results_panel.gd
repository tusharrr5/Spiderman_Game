class_name ResultsPanel
extends Control
## End-of-run results card: stats breakdown, rank letter, stars, score and tokens earned.

var _rank: Label


func show_result(title: String, r: Dictionary, new_best: bool) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.13, 0.94)
	sb.border_color = Color(0.95, 0.3, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(170, 70)
	panel.size = Vector2(300, 200)
	add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	hb.add_child(vb)
	vb.add_child(_lbl(title, 12, Color(1, 0.9, 0.7)))
	var mins := int(r["time"]) / 60
	var secs := int(r["time"]) % 60
	for row in [["TIME", "%d:%02d" % [mins, secs]], ["HITS", str(r["hits"])], ["MAX COMBO", str(r["max_combo"])],
			["PARRIES", str(r["parries"])], ["SPECIALS", str(r["specials"])], ["DAMAGE TAKEN", str(r["taken"])],
			["SCORE", str(r["score"]) + ("  NEW BEST!" if new_best else "")], ["TOKENS", "+%d" % int(r["tokens"])]]:
		vb.add_child(_lbl("%-13s %s" % [row[0], row[1]], 8, Color(0.85, 0.88, 1.0)))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(right)
	_rank = _lbl(String(r["rank"]), 44, _rank_color(String(r["rank"])))
	_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_rank)
	var stars := ""
	for i in range(3):
		stars += "★" if i < int(r["stars"]) else "☆"
	var sl := _lbl(stars, 14, Color(1, 0.85, 0.3))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(sl)
	_rank.pivot_offset = Vector2(20, 26)
	_rank.scale = Vector2(2.2, 2.2)
	var tw := create_tween()
	tw.tween_property(_rank, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _rank_color(r: String) -> Color:
	match r:
		"S": return Color(1.0, 0.82, 0.25)
		"A": return Color(0.45, 0.95, 0.55)
		"B": return Color(0.45, 0.75, 1.0)
		"C": return Color(0.85, 0.7, 1.0)
	return Color(0.8, 0.8, 0.8)


func _lbl(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
