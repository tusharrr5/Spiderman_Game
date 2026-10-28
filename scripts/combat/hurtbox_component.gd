class_name HurtboxComponent
extends Area2D
## Hurtbox receiver attached to an actor with a HealthComponent.

signal hit_received(damage: int, knockback: Vector2, attack_type: String, stun_duration: float)

@export var health_component: HealthComponent
var owner_actor: Node2D = null


func _ready() -> void:
	monitoring = true
	monitorable = true
	if owner_actor == null and get_parent() is Node2D:
		owner_actor = get_parent() as Node2D


func receive_hit(damage: int, knockback: Vector2, attack_type: String = "melee", stun_duration: float = 0.25) -> bool:
	if health_component == null:
		return false
	var applied := health_component.take_damage(damage, knockback, attack_type)
	if applied:
		hit_received.emit(damage, knockback, attack_type, stun_duration)
	return applied
