class_name MovingPlatform
extends AnimatableBody2D
## Platform that ping-pongs between its start position and start + travel (crane hooks, lifts).
## Uses sync_to_physics so the player rides it smoothly.

var size: Vector2 = Vector2(64, 12)
var travel: Vector2 = Vector2(0, -80)
var period: float = 3.0
var style: String = "girder"
var _start: Vector2
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	_start = position
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
	var vis := PlatformVisual.new()
	vis.rect = Rect2(-size * 0.5, size)
	vis.style = style
	add_child(vis)
	var cable := Line2D.new()
	cable.width = 1.5
	cable.default_color = Color(0.15, 0.13, 0.2, 0.9)
	cable.add_point(Vector2(0, -size.y * 0.5))
	cable.add_point(Vector2(0, -size.y * 0.5 - 420.0))
	cable.z_index = -2
	add_child(cable)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := 0.5 - 0.5 * cos(_t / period * TAU)
	position = _start + travel * k
