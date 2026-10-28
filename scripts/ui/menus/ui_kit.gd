class_name UIKit
extends RefCounted
## Shared menu styling so every screen uses the same typography, colours and button states.

const ACCENT: Color = Color(0.86, 0.18, 0.24)
const PANEL: Color = Color(0.05, 0.06, 0.13, 0.9)


static func box(bg: Color, border: Color, radius: int = 6, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


static func style_button(b: Button, font_size: int = 12) -> void:
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", box(Color(0.1, 0.12, 0.25, 0.92), Color(0.35, 0.4, 0.65)))
	b.add_theme_stylebox_override("hover", box(Color(0.16, 0.18, 0.36, 0.95), ACCENT))
	b.add_theme_stylebox_override("focus", box(Color(0.16, 0.18, 0.36, 0.95), Color(1, 0.85, 0.4), 6, 2))
	b.add_theme_stylebox_override("pressed", box(ACCENT, Color(1, 1, 1)))
	b.add_theme_stylebox_override("disabled", box(Color(0.08, 0.08, 0.12, 0.85), Color(0.2, 0.2, 0.28)))
	b.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.46, 0.55))
	b.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06))
	b.add_theme_constant_override("outline_size", 3)
	b.focus_entered.connect(func() -> void: Audio.play_sfx("menu_move", 0.5, 0.0))
	b.pressed.connect(func() -> void: Audio.play_sfx("menu_select", 0.7, 0.0))


static func button(text: String, font_size: int = 12, min_size: Vector2 = Vector2(180, 30)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	style_button(b, font_size)
	return b


static func label(text: String, size: int, color: Color = Color(0.95, 0.95, 1.0), outline: int = 5) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.07))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


static func backdrop(parent: Control, image_path: String, dim: float = 0.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(image_path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(t)
	parent.add_child(t)
	if dim > 0.0:
		var d := ColorRect.new()
		d.color = Color(0, 0, 0, dim)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		full_rect(d)
		parent.add_child(d)
	return t


static func format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
