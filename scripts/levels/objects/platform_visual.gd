class_name PlatformVisual
extends Node2D
## Draws a rooftop / wall / girder block: a tiled surface texture with a lit top cap and side shading.

var rect: Rect2 = Rect2(0, 0, 32, 32)
var style: String = "concrete"
var show_cap: bool = true
var _tex: Texture2D
var _cap: Texture2D


func _ready() -> void:
	_tex = load("res://assets/tiles/%s.png" % style)
	_cap = load("res://assets/tiles/%s_cap.png" % style)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -1
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		draw_rect(rect, Color(0.3, 0.3, 0.35))
		return
	# textures are authored at 2x -> draw in a half-scale space so one tile covers 32x32 game units
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.5, 0.5))
	var r2 := Rect2(rect.position * 2.0, rect.size * 2.0)
	if style == "girder":
		draw_rect(r2, Color(0.08, 0.06, 0.1, 0.35))
	draw_texture_rect(_tex, r2, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# depth shading toward the bottom and right edge
	var shade_h := minf(rect.size.y, 60.0)
	draw_rect(Rect2(rect.position.x, rect.end.y - shade_h, rect.size.x, shade_h), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(rect.end.x - 3, rect.position.y, 3, rect.size.y), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(rect.position.x, rect.position.y, 2, rect.size.y), Color(1, 1, 1, 0.08))
	if show_cap and _cap != null and rect.size.y >= 10.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.5, 0.5))
		draw_texture_rect(_cap, Rect2(rect.position.x * 2.0, rect.position.y * 2.0 - 4.0, rect.size.x * 2.0, 18.0), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if show_cap:
		draw_rect(rect, Color(0.07, 0.06, 0.1, 0.9), false, 1.0)
