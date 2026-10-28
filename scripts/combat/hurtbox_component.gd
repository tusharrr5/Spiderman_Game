class_name HurtboxComponent
extends Area2D
## Hurtbox receiver attached to an actor with a HealthComponent.

signal hit_received(damage: int, knockback: Vector2, attack_type: String, stun_duration: float)

@export var health_component: HealthComponent
var owner_actor: Node2D = null
## Optional guard hook: func(damage: int, knockback: Vector2, attack_type: String, attacker: Node) -> int.
## Returns the damage to apply (block chip / armour), or a negative value to cancel the hit (parry).
var guard: Callable


func _ready() -> void:
	monitoring = true
	monitorable = true
	if owner_actor == null and get_parent() is Node2D:
		owner_actor = get_parent() as Node2D


func receive_hit(damage: int, knockback: Vector2, attack_type: String = "melee", stun_duration: float = 0.25, attacker: Node = null) -> bool:
	if health_component == null:
		return false
	if guard.is_valid() and not health_component.is_invulnerable and not health_component.is_dead:
		damage = int(guard.call(damage, knockback, attack_type, attacker))
		if damage < 0:
			return false
	var applied := health_component.take_damage(damage, knockback, attack_type)
	if applied:
		hit_received.emit(damage, knockback, attack_type, stun_duration)
	return applied
