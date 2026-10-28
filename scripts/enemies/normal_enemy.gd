class_name NormalEnemy
extends CharacterBody2D
## Normal Street Thug Enemy for Phase 1 Prototype.
## Patrols between horizontal bounds, approaches the player when in detection range,
## performs a telegraphed baton strike, reacts to hits/web-snares, and resets cleanly on retry.

signal enemy_defeated(enemy: NormalEnemy)

enum AIState {
	PATROL,
	APPROACH,
	TELEGRAPH,
	ATTACK,
	HURT,
	WEB_SNARED,
	DEFEATED
}

@export var patrol_distance: float = 90.0
@export var patrol_speed: float = 55.0
@export var chase_speed: float = 92.0
@export var detection_range: float = 155.0
@export var attack_range: float = 28.0
@export var telegraph_duration: float = 0.42
@export var attack_duration: float = 0.26
@export var attack_cooldown: float = 0.95
@export var attack_damage: int = 14

const GRAVITY: float = 690.0

var sfx_hit: AudioStream = preload("res://assets/audio/hit.wav")

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var attack_hitbox: HitboxComponent = $AttackHitbox
@onready var status_label: Label = $StatusLabel
@onready var hp_bar: ColorRect = $HPBarBg/HPBarFill
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var state: AIState = AIState.PATROL
var spawn_position: Vector2 = Vector2.ZERO
var facing_dir: float = -1.0
var _patrol_min_x: float = 0.0
var _patrol_max_x: float = 0.0
var _state_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _anim_clock: float = 0.0


func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	_patrol_min_x = spawn_position.x - patrol_distance
	_patrol_max_x = spawn_position.x + patrol_distance

	hurtbox.owner_actor = self
	hurtbox.health_component = health_component
	attack_hitbox.owner_actor = self

	hurtbox.hit_received.connect(_on_hit_received)
	health_component.health_changed.connect(_on_health_changed)
	health_component.defeated.connect(_on_defeated)
	_update_visuals()


func reset_enemy() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	facing_dir = -1.0
	state = AIState.PATROL
	_state_timer = 0.0
	_cooldown_timer = 0.0
	visible = true
	collision_layer = 4
	collision_mask = 1
	hurtbox.monitoring = true
	hurtbox.monitorable = true
	attack_hitbox.deactivate()
	status_label.text = ""
	health_component.reset_health()
	_update_visuals()


func apply_combat_hit(damage: int, knockback: Vector2, attack_type: String = "melee", stun_duration: float = 0.25) -> bool:
	return hurtbox.receive_hit(damage, knockback, attack_type, stun_duration)


func _physics_process(delta: float) -> void:
	if state == AIState.DEFEATED:
		return

	_anim_clock += delta
	if _cooldown_timer > 0.0:
		_cooldown_timer = max(0.0, _cooldown_timer - delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var player := _get_active_player()

	match state:
		AIState.PATROL:
			status_label.text = ""
			velocity.x = facing_dir * patrol_speed
			if global_position.x <= _patrol_min_x:
				facing_dir = 1.0
			elif global_position.x >= _patrol_max_x:
				facing_dir = -1.0
			if player != null and global_position.distance_to(player.global_position) <= detection_range:
				state = AIState.APPROACH

		AIState.APPROACH:
			status_label.text = ""
			if player == null or global_position.distance_to(player.global_position) > detection_range * 1.35:
				state = AIState.PATROL
			else:
				var dx := player.global_position.x - global_position.x
				facing_dir = -1.0 if dx < 0.0 else 1.0
				if abs(dx) <= attack_range and abs(player.global_position.y - global_position.y) < 36.0:
					velocity.x = 0.0
					if _cooldown_timer <= 0.0:
						state = AIState.TELEGRAPH
						_state_timer = telegraph_duration
						status_label.text = "!"
				else:
					velocity.x = facing_dir * chase_speed

		AIState.TELEGRAPH:
			velocity.x = 0.0
			status_label.text = "!"
			_state_timer -= delta
			if _state_timer <= 0.0:
				state = AIState.ATTACK
				_state_timer = attack_duration
				status_label.text = ""
				attack_hitbox.position = Vector2(facing_dir * 16.0, 0.0)
				attack_hitbox.activate(attack_damage, Vector2(145.0, -110.0), facing_dir, "thug_baton", 0.25)

		AIState.ATTACK:
			velocity.x = facing_dir * 30.0
			_state_timer -= delta
			if _state_timer <= 0.0:
				attack_hitbox.deactivate()
				_cooldown_timer = attack_cooldown
				state = AIState.APPROACH

		AIState.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 480.0 * delta)
			_state_timer -= delta
			if _state_timer <= 0.0:
				status_label.text = ""
				state = AIState.APPROACH

		AIState.WEB_SNARED:
			velocity.x = move_toward(velocity.x, 0.0, 620.0 * delta)
			status_label.text = "WEBBED!"
			_state_timer -= delta
			if _state_timer <= 0.0:
				status_label.text = ""
				state = AIState.APPROACH

	move_and_slide()
	_update_visuals()


func _on_hit_received(_damage: int, knockback: Vector2, attack_type: String, stun_duration: float) -> void:
	if state == AIState.DEFEATED:
		return
	attack_hitbox.deactivate()
	velocity = knockback
	if sfx_player != null:
		sfx_player.stream = sfx_hit
		sfx_player.play()
	if attack_type == "web_shot":
		state = AIState.WEB_SNARED
		_state_timer = max(0.85, stun_duration)
	else:
		state = AIState.HURT
		_state_timer = max(0.24, stun_duration)
		status_label.text = "HIT!"


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	if hp_bar != null and max_hp > 0:
		hp_bar.size.x = 24.0 * (float(current_hp) / float(max_hp))


func _on_defeated() -> void:
	state = AIState.DEFEATED
	attack_hitbox.deactivate()
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	status_label.text = "KO!"
	if sfx_player != null:
		sfx_player.stream = sfx_hit
		sfx_player.play()
	visible = false
	enemy_defeated.emit(self)


func _get_active_player() -> PlayerController:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.size() > 0 and nodes[0] is PlayerController:
		var p := nodes[0] as PlayerController
		if p.current_state != PlayerController.State.DEFEATED:
			return p
	return null


func _update_visuals() -> void:
	if sprite == null:
		return
	sprite.flip_h = facing_dir < 0.0
	match state:
		AIState.PATROL, AIState.APPROACH:
			if abs(velocity.x) > 5.0:
				sprite.frame = 1 if int(_anim_clock * 7.0) % 2 == 0 else 2
			else:
				sprite.frame = 0
			sprite.modulate = Color(1, 1, 1, 1)
		AIState.TELEGRAPH:
			sprite.frame = 3
			sprite.modulate = Color(1.0, 0.92, 0.55, 1.0)
		AIState.ATTACK:
			sprite.frame = 4
			sprite.modulate = Color(1, 1, 1, 1)
		AIState.HURT:
			sprite.frame = 5
			sprite.modulate = Color(1.0, 0.55, 0.55, 1.0)
		AIState.WEB_SNARED:
			sprite.frame = 0
			sprite.modulate = Color(0.82, 0.95, 1.0, 1.0)
