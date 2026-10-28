class_name FollowerNPC
extends Node2D
## Rescued character (MJ) who stays close behind the hero during the escape. Not a physics body: she
## trails the player's recent path so she never gets stuck, and clings on ("held") while he is airborne.

var sheet_key: String = "mj"
var target: PlayerController
var _sprite: SpriteAnimator
var _trail: Array[Vector2] = []
var _prev: Vector2


func _ready() -> void:
	z_index = 2
	_sprite = SpriteAnimator.new()
	add_child(_sprite)
	_sprite.setup(sheet_key, 14.0)
	_sprite.play("cheer")
	_prev = global_position


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_trail.append(target.global_position)
	if _trail.size() > 16:
		_trail.pop_front()
	var goal: Vector2 = _trail[0] + Vector2(-target.facing_dir * 14.0, 0.0)
	if global_position.distance_to(target.global_position) > 220.0:
		global_position = goal
	global_position = global_position.lerp(goal, 0.25)
	var moved := global_position - _prev
	_prev = global_position
	if not target.is_on_floor() and target.current_state != PlayerController.State.WALL_CLIMBING:
		_sprite.play("held")
	elif absf(moved.x) > 0.6:
		_sprite.play("run")
		_sprite.flip_h = moved.x < 0.0
	else:
		_sprite.play("idle")
		_sprite.flip_h = target.global_position.x < global_position.x
