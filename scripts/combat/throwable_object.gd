class_name ThrowableObject
extends Area2D
## Dedicated throwable street crate/canister that the player can yank with webbing and hurl ('L')
## at enemies or the boss for heavy impact damage and knockback.

@export var throw_speed: float = 310.0
@export var fall_gravity: float = 420.0
@export var damage: int = 28
@export var stun_duration: float = 0.65

var initial_spawn_position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var is_thrown: bool = false
var is_consumed: bool = false
var thrower: Node2D = null
var _lifetime: float = 0.0


func _ready() -> void:
	add_to_group("throwables")
	if initial_spawn_position == Vector2.ZERO:
		initial_spawn_position = global_position
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func reset_object() -> void:
	is_thrown = false
	is_consumed = false
	velocity = Vector2.ZERO
	_lifetime = 0.0
	rotation = 0.0
	visible = true
	monitoring = true
	monitorable = true
	global_position = initial_spawn_position


func launch(dir_sign: float, actor: Node2D) -> void:
	if is_thrown or is_consumed:
		return
	thrower = actor
	var d := -1.0 if dir_sign < 0.0 else 1.0
	global_position = actor.global_position + Vector2(d * 18.0, -10.0)
	velocity = Vector2(d * throw_speed, -95.0)
	is_thrown = true
	_lifetime = 0.0


func _physics_process(delta: float) -> void:
	if not is_thrown or is_consumed:
		return
	velocity.y += fall_gravity * delta
	global_position += velocity * delta
	rotation += 9.0 * delta * sign(velocity.x)
	_lifetime += delta
	if _lifetime > 2.5:
		_deactivate_after_impact()


func _on_area_entered(area: Area2D) -> void:
	if not is_thrown or is_consumed or area == null:
		return
	if area is HurtboxComponent:
		var hurtbox := area as HurtboxComponent
		if hurtbox.owner_actor == thrower:
			return
		var dir := -1.0 if velocity.x < 0.0 else 1.0
		var kb := Vector2(210.0 * dir, -110.0)
		if hurtbox.receive_hit(damage, kb, "thrown_object", stun_duration):
			_spawn_debris_particles()
			_deactivate_after_impact()


func _on_body_entered(body: Node2D) -> void:
	if not is_thrown or is_consumed or body == null or body == thrower:
		return
	if body.has_method("apply_combat_hit"):
		var dir := -1.0 if velocity.x < 0.0 else 1.0
		var kb := Vector2(210.0 * dir, -110.0)
		if body.apply_combat_hit(damage, kb, "thrown_object", stun_duration):
			_spawn_debris_particles()
			_deactivate_after_impact()
	elif body is StaticBody2D and _lifetime > 0.08:
		_spawn_debris_particles()
		_deactivate_after_impact()


func _spawn_debris_particles() -> void:
	if get_parent() == null:
		return
	var debris := CPUParticles2D.new()
	debris.global_position = global_position
	debris.emitting = true
	debris.one_shot = true
	debris.amount = 12
	debris.lifetime = 0.35
	debris.explosiveness = 0.95
	debris.spread = 180.0
	debris.gravity = Vector2(0, 320)
	debris.initial_velocity_min = 45.0
	debris.initial_velocity_max = 110.0
	debris.color = Color(0.75, 0.50, 0.22, 1.0)
	get_parent().add_child(debris)
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(debris.queue_free)


func _deactivate_after_impact() -> void:
	is_consumed = true
	is_thrown = false
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
