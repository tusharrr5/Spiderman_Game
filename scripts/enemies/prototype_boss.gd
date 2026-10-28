class_name PrototypeBoss
extends CharacterBody2D
## Prototype Boss ("The Rhino-Enforcer") for Phase 1.
## Features:
## - Separate HUD health bar triggered when the player enters the Boss Arena.
## - Two distinct telegraphed attack behaviours:
##   1) Armored Dash Charge across the arena floor.
##   2) Jumping Shockwave Ground Slam.
## - Explicit RECOVERY (Vulnerable) window after each attack where the player can counterattack
##   for full/bonus damage, preventing a passive damage-sponge encounter.

signal boss_engaged(boss_name: String, current_hp: int, max_hp: int)
signal boss_health_updated(current_hp: int, max_hp: int)
signal boss_status_changed(status_text: String)
signal boss_defeated()

enum BossState {
	DORMANT,
	IDLE_POSITIONING,
	TELEGRAPH_CHARGE,
	ATTACK_CHARGE,
	TELEGRAPH_SLAM,
	ATTACK_SLAM_AIR,
	ATTACK_SLAM_IMPACT,
	RECOVERY_VULNERABLE,
	DEFEATED
}

@export var boss_display_name: String = "ARMORED ENFORCER (PROTOTYPE BOSS)"
@export var arena_trigger_x: float = 1040.0
@export var arena_left_x: float = 1060.0
@export var arena_right_x: float = 1480.0
@export var move_speed: float = 85.0
@export var charge_speed: float = 255.0
@export var slam_jump_vel: float = -310.0

const GRAVITY: float = 690.0

var sfx_warn: AudioStream = preload("res://assets/audio/boss_warn.wav")
var sfx_hit: AudioStream = preload("res://assets/audio/hit.wav")
var sfx_defeat: AudioStream = preload("res://assets/audio/defeat.wav")

@onready var sprite: SpriteAnimator = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var body_hitbox: HitboxComponent = $BodyHitbox
@onready var telegraph_label: Label = $TelegraphLabel
@onready var shockwave_particles: CPUParticles2D = $ShockwaveParticles
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var state: BossState = BossState.DORMANT
var spawn_position: Vector2 = Vector2.ZERO
var facing_dir: float = -1.0
var _state_timer: float = 0.0
var _attack_cycle: int = 0
var _engaged: bool = false


func _ready() -> void:
	add_to_group("boss")
	spawn_position = global_position
	hurtbox.owner_actor = self
	hurtbox.health_component = health_component
	body_hitbox.owner_actor = self

	hurtbox.hit_received.connect(_on_hit_received)
	health_component.health_changed.connect(_on_health_changed)
	health_component.defeated.connect(_on_defeated)
	sprite.setup("brick", 21.0)
	_update_visuals()


func reset_boss() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	facing_dir = -1.0
	state = BossState.DORMANT
	_state_timer = 0.6
	_attack_cycle = 0
	_engaged = false
	visible = true
	modulate = Color(1, 1, 1, 1)
	collision_layer = 4
	collision_mask = 1
	hurtbox.monitoring = true
	hurtbox.monitorable = true
	body_hitbox.deactivate()
	telegraph_label.text = ""
	health_component.reset_health()
	_update_visuals()


func apply_combat_hit(damage: int, knockback: Vector2, attack_type: String = "melee", stun_duration: float = 0.25) -> bool:
	return hurtbox.receive_hit(damage, knockback, attack_type, stun_duration)


## Parried charges and slams leave Brick open.
func apply_parry_stun(duration: float) -> void:
	if state in [BossState.TELEGRAPH_CHARGE, BossState.ATTACK_CHARGE, BossState.TELEGRAPH_SLAM, BossState.ATTACK_SLAM_IMPACT, BossState.IDLE_POSITIONING]:
		_enter_state(BossState.RECOVERY_VULNERABLE, duration + 0.4)


func is_defeated() -> bool:
	return state == BossState.DEFEATED


func _physics_process(delta: float) -> void:
	if state == BossState.DEFEATED:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var player := _get_active_player()

	match state:
		BossState.DORMANT:
			velocity.x = 0.0
			if player != null and player.global_position.x >= arena_trigger_x:
				_engaged = true
				boss_engaged.emit(boss_display_name, health_component.current_health, health_component.max_health)
				_enter_state(BossState.IDLE_POSITIONING, 0.75)

		BossState.IDLE_POSITIONING:
			telegraph_label.text = ""
			if player != null:
				var dx := player.global_position.x - global_position.x
				facing_dir = -1.0 if dx < 0.0 else 1.0
				if abs(dx) > 95.0:
					velocity.x = facing_dir * move_speed
				else:
					velocity.x = 0.0
			_state_timer -= delta
			if _state_timer <= 0.0:
				_attack_cycle += 1
				if _attack_cycle % 2 == 1:
					_play_sfx(sfx_warn)
					boss_status_changed.emit("WARNING: ARMORED DASH CHARGE!")
					_enter_state(BossState.TELEGRAPH_CHARGE, 0.68)
				else:
					_play_sfx(sfx_warn)
					boss_status_changed.emit("WARNING: SHOCKWAVE SLAM!")
					_enter_state(BossState.TELEGRAPH_SLAM, 0.68)

		BossState.TELEGRAPH_CHARGE:
			velocity.x = 0.0
			telegraph_label.text = "!! CHARGE !!"
			if player != null:
				facing_dir = -1.0 if (player.global_position.x < global_position.x) else 1.0
			_state_timer -= delta
			if _state_timer <= 0.0:
				telegraph_label.text = ""
				body_hitbox.position = Vector2(facing_dir * 16.0, 0.0)
				body_hitbox.activate(20, Vector2(240.0, -140.0), facing_dir, "boss_charge", 0.35)
				_enter_state(BossState.ATTACK_CHARGE, 0.62)

		BossState.ATTACK_CHARGE:
			velocity.x = facing_dir * charge_speed
			_state_timer -= delta
			var hit_arena_bound := (global_position.x <= arena_left_x and facing_dir < 0.0) or (global_position.x >= arena_right_x and facing_dir > 0.0)
			if _state_timer <= 0.0 or hit_arena_bound or is_on_wall():
				body_hitbox.deactivate()
				velocity.x = 0.0
				boss_status_changed.emit("BOSS EXHAUSTED - COUNTERATTACK NOW!")
				_enter_state(BossState.RECOVERY_VULNERABLE, 1.85)

		BossState.TELEGRAPH_SLAM:
			velocity.x = 0.0
			telegraph_label.text = "!! JUMP SLAM !!"
			if player != null:
				facing_dir = -1.0 if (player.global_position.x < global_position.x) else 1.0
			_state_timer -= delta
			if _state_timer <= 0.0:
				telegraph_label.text = ""
				var target_vx := facing_dir * 135.0
				if player != null:
					target_vx = clamp((player.global_position.x - global_position.x) * 1.4, -180.0, 180.0)
				velocity = Vector2(target_vx, slam_jump_vel)
				_enter_state(BossState.ATTACK_SLAM_AIR, 1.2)

		BossState.ATTACK_SLAM_AIR:
			_state_timer -= delta
			if is_on_floor() and velocity.y >= 0.0:
				velocity.x = 0.0
				body_hitbox.position = Vector2.ZERO
				body_hitbox.activate(24, Vector2(260.0, -170.0), facing_dir, "boss_slam", 0.4)
				if shockwave_particles != null:
					shockwave_particles.restart()
					shockwave_particles.emitting = true
				_play_sfx(sfx_hit)
				Fx.shake(5.0, 0.25)
				Fx.burst(get_parent(), global_position + Vector2(0, 20), Color(0.8, 0.75, 0.7), 18, 140.0, 160.0, 0.4)
				_enter_state(BossState.ATTACK_SLAM_IMPACT, 0.28)
			elif _state_timer <= 0.0:
				_enter_state(BossState.RECOVERY_VULNERABLE, 1.65)

		BossState.ATTACK_SLAM_IMPACT:
			velocity.x = 0.0
			_state_timer -= delta
			if _state_timer <= 0.0:
				body_hitbox.deactivate()
				boss_status_changed.emit("BOSS RECOVERING - STRIKE NOW!")
				_enter_state(BossState.RECOVERY_VULNERABLE, 1.85)

		BossState.RECOVERY_VULNERABLE:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			telegraph_label.text = "VULNERABLE!"
			_state_timer -= delta
			if _state_timer <= 0.0:
				telegraph_label.text = ""
				boss_status_changed.emit("")
				_enter_state(BossState.IDLE_POSITIONING, 0.70)

	move_and_slide()
	global_position.x = clamp(global_position.x, arena_left_x, arena_right_x)
	_update_visuals()


func _enter_state(new_state: BossState, duration: float) -> void:
	state = new_state
	_state_timer = duration


func _on_hit_received(damage: int, knockback: Vector2, attack_type: String, _stun_duration: float) -> void:
	if state == BossState.DEFEATED:
		return
	if not _engaged:
		_engaged = true
		boss_engaged.emit(boss_display_name, health_component.current_health, health_component.max_health)

	_play_sfx(sfx_hit)

	# Bonus vulnerability damage when player counterattacks during RECOVERY_VULNERABLE or throws a crate
	if state == BossState.RECOVERY_VULNERABLE or attack_type == "thrown_object":
		var bonus := int(round(float(damage) * 0.35))
		if bonus > 0 and not health_component.is_dead:
			health_component.current_health = max(0, health_component.current_health - bonus)
			health_component.health_changed.emit(health_component.current_health, health_component.max_health)
			if health_component.current_health <= 0:
				health_component.is_dead = true
				health_component.defeated.emit()
				return
		velocity.x = knockback.x * 0.45
	elif attack_type == "web_shot" and state == BossState.IDLE_POSITIONING:
		# Webbing the boss briefly slows its positioning
		_state_timer += 0.25


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	if _engaged:
		boss_health_updated.emit(current_hp, max_hp)


func _on_defeated() -> void:
	state = BossState.DEFEATED
	body_hitbox.deactivate()
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	telegraph_label.text = "DEFEATED!"
	boss_status_changed.emit("PROTOTYPE BOSS DEFEATED!")
	_play_sfx(sfx_defeat)
	Fx.shake(4.0, 0.3)
	boss_defeated.emit()


func _get_active_player() -> PlayerController:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.size() > 0 and nodes[0] is PlayerController:
		var p := nodes[0] as PlayerController
		if p.current_state != PlayerController.State.DEFEATED:
			return p
	return null


func _play_sfx(stream: AudioStream) -> void:
	if sfx_player != null and stream != null:
		sfx_player.stream = stream
		sfx_player.play()


func _update_visuals() -> void:
	if sprite == null:
		return
	sprite.flip_h = facing_dir < 0.0
	sprite.modulate = Color(1, 1, 1, 1)
	match state:
		BossState.DORMANT:
			sprite.play("idle")
		BossState.IDLE_POSITIONING:
			sprite.play("walk" if absf(velocity.x) > 5.0 else "idle")
		BossState.TELEGRAPH_CHARGE, BossState.TELEGRAPH_SLAM:
			sprite.play("telegraph")
			sprite.modulate = Color(1.0, 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.03), 0.55, 1.0)
		BossState.ATTACK_CHARGE:
			sprite.play("attack")
		BossState.ATTACK_SLAM_AIR:
			sprite.play("slam_air")
		BossState.ATTACK_SLAM_IMPACT:
			sprite.play("slam_impact")
		BossState.RECOVERY_VULNERABLE:
			sprite.play("vulnerable")
			sprite.modulate = Color(0.75, 0.95, 1.0, 1.0)
		BossState.DEFEATED:
			sprite.play("ko")
