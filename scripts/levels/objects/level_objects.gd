class_name LevelObjects
extends RefCounted
## Factory helpers that build the reusable level pieces from compact level data.
## Each piece is a small node with its own script so it can be reused across every chapter.

const TILE_DIR: String = "res://assets/tiles/"
const PROP_DIR: String = "res://assets/props/"


static func solid(rect: Rect2, style: String, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.one_way_collision = one_way
	body.add_child(col)
	var vis := PlatformVisual.new()
	vis.rect = Rect2(-rect.size * 0.5, rect.size)
	vis.style = style
	body.add_child(vis)
	body.add_to_group("level_solids")
	return body


static func prop(name: String, pos: Vector2, scale_k: float = 1.0, flip: bool = false, z: int = -1) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(PROP_DIR + name + ".png")
	s.centered = true
	s.scale = Vector2(0.5, 0.5) * scale_k
	s.flip_h = flip
	# props are placed by their bottom-centre
	s.position = pos - Vector2(0, s.texture.get_height() * 0.25 * scale_k)
	s.z_index = z
	return s


static func web_anchor(pos: Vector2) -> Sprite2D:
	var s := prop("web_anchor", pos + Vector2(0, 12))
	s.add_to_group("web_anchors")
	s.z_index = 1
	# web anchors must use their centre as the tether point
	s.position = pos
	return s
