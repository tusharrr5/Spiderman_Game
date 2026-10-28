class_name HitboxComponent
extends Area2D
## Active attack hitbox that tracks hit targets per swing/activation so each valid attack
## applies damage at most once per target.

signal hit_landed(target: Node, damage_dealt: int, attack_id: String)

@export var damage: int = 15
@export var base_knockback: Vector2 = Vector2(160.0, -70.0)
@export var attack_type: String = "punch"
@export var stun_duration: float = 0.25

var owner_actor: Node2D = null
var facing_sign: float = 1.0
var is_active: bool = false
var _hit_registry: Dictionary = {}


func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func activate(dmg: int, knockback: Vector2, dir_sign: float, atk_name: String = "punch", stun: float = 0.25) -> void:
	damage = dmg
	base_knockback = knockback
	facing_sign = -1.0 if dir_sign < 0.0 else 1.0
	attack_type = atk_name
	stun_duration = stun
	_hit_registry.clear()
	is_active = true
	monitoring = true
	monitorable = true

	# Immediately check overlapping areas/bodies on activation frame
	call_deferred("_check_existing_overlaps")


func deactivate() -> void:
	is_active = false
	monitoring = false
	monitorable = false
	_hit_registry.clear()


func _check_existing_overlaps() -> void:
	if not is_active:
		return
	for area in get_overlapping_areas():
		_on_area_entered(area)
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _on_area_entered(area: Area2D) -> void:
	if not is_active or area == null:
		return
	if area is HurtboxComponent:
		var hurtbox := area as HurtboxComponent
		var target := hurtbox.owner_actor if hurtbox.owner_actor != null else hurtbox.get_parent()
		if target == owner_actor or target == null:
			return
		var id := target.get_instance_id()
		if _hit_registry.has(id):
			return
		var kb := Vector2(abs(base_knockback.x) * facing_sign, base_knockback.y)
		if hurtbox.receive_hit(damage, kb, attack_type, stun_duration):
			_hit_registry[id] = true
			hit_landed.emit(target, damage, attack_type)


func _on_body_entered(body: Node2D) -> void:
	if not is_active or body == null or body == owner_actor:
		return
	var id := body.get_instance_id()
	if _hit_registry.has(id):
		return
	if body.has_method("apply_combat_hit"):
		var kb := Vector2(abs(base_knockback.x) * facing_sign, base_knockback.y)
		if body.apply_combat_hit(damage, kb, attack_type, stun_duration):
			_hit_registry[id] = true
			hit_landed.emit(body, damage, attack_type)
