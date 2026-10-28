class_name HealthComponent
extends Node
## Reusable health and damage component for Player, Normal Enemies, and Bosses.
## Enforces brief invulnerability windows so repeated collisions never drain health every frame.

signal health_changed(current_hp: int, max_hp: int)
signal damaged(amount: int, knockback: Vector2, source_type: String)
signal invulnerability_changed(is_invulnerable: bool)
signal defeated()

@export var max_health: int = 100
@export var invulnerability_duration: float = 0.65

var current_health: int = 100
var is_invulnerable: bool = false
var is_dead: bool = false
var _invuln_timer: float = 0.0


func _ready() -> void:
	reset_health()


func _process(delta: float) -> void:
	if is_invulnerable and _invuln_timer > 0.0:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			is_invulnerable = false
			invulnerability_changed.emit(false)


func reset_health() -> void:
	is_dead = false
	is_invulnerable = false
	_invuln_timer = 0.0
	current_health = max_health
	health_changed.emit(current_health, max_health)
	invulnerability_changed.emit(false)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, source_type: String = "melee") -> bool:
	if is_dead or is_invulnerable or amount <= 0:
		return false

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	damaged.emit(amount, knockback, source_type)

	if current_health <= 0:
		is_dead = true
		defeated.emit()
	elif invulnerability_duration > 0.0:
		is_invulnerable = true
		_invuln_timer = invulnerability_duration
		invulnerability_changed.emit(true)

	return true


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
