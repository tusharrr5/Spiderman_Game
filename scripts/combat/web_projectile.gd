class_name WebProjectile
extends Area2D
## Web shot projectile fired by the player ('K' key / Web button).
## Deals light web damage, applies a brief web-snare slow/stun to enemies, and cleans up safely.

@export var speed: float = 340.0
@export var damage: int = 12
@export var snare_duration: float = 1.15
@export var max_lifetime: float = 1.25

var direction: float = 1.0
var shooter: Node2D = null
var _age: float = 0.0
var _consumed: bool = false


func _ready() -> void:
	add_to_group("projectiles")
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(spawn_pos: Vector2, dir_sign: float, owner_node: Node2D) -> void:
	global_position = spawn_pos
	direction = -1.0 if dir_sign < 0.0 else 1.0
	shooter = owner_node
	scale.x = direction


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	global_position.x += direction * speed * delta
	_age += delta
	if _age >= max_lifetime:
		_consume_and_free()


func _on_area_entered(area: Area2D) -> void:
	if _consumed or area == null:
		return
	if area is HurtboxComponent:
		var hurtbox := area as HurtboxComponent
		if hurtbox.owner_actor == shooter:
			return
		var kb := Vector2(75.0 * direction, -35.0)
		if hurtbox.receive_hit(damage, kb, "web_shot", snare_duration):
			_spawn_web_burst()
			_consume_and_free()


func _on_body_entered(body: Node2D) -> void:
	if _consumed or body == null or body == shooter:
		return
	if body.has_method("apply_combat_hit"):
		var kb := Vector2(75.0 * direction, -35.0)
		body.apply_combat_hit(damage, kb, "web_shot", snare_duration)
		_spawn_web_burst()
		_consume_and_free()
	elif body is StaticBody2D or body is TileMap:
		_spawn_web_burst()
		_consume_and_free()


func _spawn_web_burst() -> void:
	if get_parent() == null:
		return
	var burst := CPUParticles2D.new()
	burst.global_position = global_position
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 10
	burst.lifetime = 0.25
	burst.explosiveness = 0.95
	burst.spread = 180.0
	burst.gravity = Vector2(0, 120)
	burst.initial_velocity_min = 35.0
	burst.initial_velocity_max = 85.0
	burst.color = Color(0.92, 0.97, 1.0, 0.95)
	get_parent().add_child(burst)
	var timer := get_tree().create_timer(0.35)
	timer.timeout.connect(burst.queue_free)


func _consume_and_free() -> void:
	if _consumed:
		return
	_consumed = true
	queue_free()
