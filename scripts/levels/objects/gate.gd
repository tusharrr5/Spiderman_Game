class_name SecurityGate
extends StaticBody2D
## Energy gate that blocks the route until its linked generator/switch is broken.

var gate_id: String = ""
var height: float = 96.0
var _sprite: Sprite2D
var _col: CollisionShape2D
var is_open: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("gates")
	_col = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, height)
	_col.shape = shape
	add_child(_col)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/props/gate.png")
	_sprite.scale = Vector2(0.5, height / 192.0)
	add_child(_sprite)


func open_gate() -> void:
	if is_open:
		return
	is_open = true
	_col.set_deferred("disabled", true)
	Audio.play_sfx("shock", 0.5)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.5)
