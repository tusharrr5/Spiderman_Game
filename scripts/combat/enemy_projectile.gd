class_name EnemyProjectile
extends Area2D
## Hostile projectile shared by gunners, the thief, drones and the Goblin.
## kinds: "bullet" (straight), "energy" (straight, faster), "bomb" (ballistic arc, explodes),
##        "bat" (straight, slight homing), "dropped_bomb" (falls straight down, explodes)

var kind: String = "bullet"
var velocity: Vector2 = Vector2.ZERO
var damage: int = 10
var gravity_force: float = 0.0
var lifetime: float = 3.0
var explode_radius: float = 0.0
var owner_node: Node = null
var _age: float = 0.0
var _done: bool = false
var _sprite: Sprite2D

const TEXTURES: Dictionary = {
	"bullet": "res://assets/props/bullet.png",
	"energy": "res://assets/props/energy_bolt.png",
	"bomb": "res://assets/props/pumpkin_bomb.png",
	"dropped_bomb": "res://assets/props/pumpkin_bomb.png",
	"bat": "res://assets/props/razor_bat.png",
}


static func spawn(parent: Node, p_kind: String, pos: Vector2, vel: Vector2, dmg: int, p_owner: Node = null) -> EnemyProjectile:
	var p := EnemyProjectile.new()
	p.kind = p_kind
	p.velocity = vel
	p.damage = dmg
	p.owner_node = p_owner
	p.position = pos
	match p_kind:
		"bomb":
			p.gravity_force = 420.0
			p.explode_radius = 34.0
			p.lifetime = 4.0
		"dropped_bomb":
			p.gravity_force = 380.0
			p.explode_radius = 30.0
			p.lifetime = 4.0
		"bat":
			p.lifetime = 2.6
	parent.add_child(p)
	return p


func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("enemy_projectiles")
	collision_layer = 16
	collision_mask = 2 | 1
	monitoring = true
	monitorable = false
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0 if kind in ["bomb", "dropped_bomb"] else 4.0
	col.shape = shape
	add_child(col)
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEXTURES.get(kind, TEXTURES["bullet"]))
	_sprite.scale = Vector2(0.5, 0.5)
	add_child(_sprite)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	velocity.y += gravity_force * delta
	if kind == "bat":
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var to := ((players[0] as Node2D).global_position - global_position).normalized()
			velocity = velocity.lerp(to * velocity.length(), 0.6 * delta)
		_sprite.rotation += 14.0 * delta
	elif kind in ["bomb", "dropped_bomb"]:
		_sprite.rotation += 5.0 * delta
		_sprite.modulate = Color(1, 1, 1) if int(_age * 10.0) % 2 == 0 else Color(1.6, 1.2, 0.8)
	else:
		_sprite.rotation = velocity.angle()
	global_position += velocity * delta
	if _age >= lifetime:
		_finish(kind in ["bomb", "dropped_bomb"])


func _on_area_entered(area: Area2D) -> void:
	if _done or not (area is HurtboxComponent):
		return
	var hb := area as HurtboxComponent
	if hb.owner_actor == null or not hb.owner_actor.is_in_group("player"):
		return
	if explode_radius > 0.0:
		_finish(true)
		return
	var dir := signf(velocity.x) if absf(velocity.x) > 1.0 else 1.0
	hb.receive_hit(damage, Vector2(120.0 * dir, -90.0), "enemy_" + kind, 0.25)
	_finish(false)


func _on_body_entered(body: Node2D) -> void:
	if _done or _age < 0.05:
		return
	if body is StaticBody2D or body is AnimatableBody2D:
		_finish(explode_radius > 0.0)


func _finish(explode: bool) -> void:
	if _done:
		return
	_done = true
	if explode:
		_explode()
	else:
		Fx.burst(get_parent(), global_position, Color(1, 0.9, 0.6), 6, 60.0, 100.0, 0.2)
	queue_free()


func _explode() -> void:
	Audio.play_sfx("explosion", 0.7)
	Fx.shake(4.0, 0.2)
	Fx.burst(get_parent(), global_position, Color(1.0, 0.55, 0.15), 22, 150.0, 120.0, 0.45)
	Fx.burst(get_parent(), global_position, Color(1.0, 0.9, 0.5), 10, 80.0, 60.0, 0.3)
	for p in get_tree().get_nodes_in_group("player"):
		var pc := p as PlayerController
		if pc != null and pc.global_position.distance_to(global_position) <= explode_radius + 10.0:
			var dir := signf(pc.global_position.x - global_position.x)
			pc.apply_combat_hit(damage, Vector2(170.0 * (dir if dir != 0.0 else 1.0), -170.0), "explosion")
