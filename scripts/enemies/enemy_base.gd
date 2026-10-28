class_name EnemyBase
extends CharacterBody2D
## Reusable enemy foundation: builds its own sprite, collision, health, hurtbox, attack hitbox and HP bar,
## and provides patrol/chase/telegraph/attack/recover/hurt/web-snare/defeat flow.
## Subclasses override the virtual hooks (_ai_custom, _begin_attack, _attack_tick, _anim_for_state).

signal enemy_defeated(enemy: Node)

enum AIState { PATROL, CHASE, TELEGRAPH, ATTACK, RECOVER, HURT, SNARED, DEFEATED, CUSTOM }

const GRAVITY: float = 690.0

@export var sheet_key: String = "thug"
@export var max_hp: int = 50
@export var body_size: Vector2 = Vector2(16, 30)
@export var flying: bool = false
@export var patrol_distance: float = 80.0
@export var patrol_speed: float = 50.0
@export var chase_speed: float = 90.0
@export var detection_range: float = 170.0
@export var attack_range: float = 30.0
@export var telegraph_duration: float = 0.45
@export var attack_duration: float = 0.28
@export var recover_duration: float = 0.5
@export var attack_cooldown: float = 1.0
@export var attack_damage: int = 12
@export var display_name: String = ""
## Enemies with this group tag count toward "defeat_group" objectives.
@export var objective_tag: String = ""
## Bosses ignore hit-stun/knockback (they handle their own reactions) so combos cannot lock them.
@export var stagger_resist: bool = false
## Falling below this y (set by the level builder to the level's pit depth) counts as defeated,
## so knocked-off enemies can never block a "defeat the group" objective.
@export var kill_y: float = 100000.0
## Chance to raise a guard against an incoming light attack (heavies, finishers and specials break it).
@export var guard_chance: float = 0.0

## Player light attacks an enemy may block; everything else (webs, hazards, scripted damage) passes through.
const GUARDABLE: Array[String] = ["jab_1", "cross_2", "kick", "dash_strike"]
const GUARD_BREAKERS: Array[String] = ["heavy", "spider_finisher", "web_slam_special", "sp2_whirl", "sp3_flurry", "sp3_final", "thrown_object", "explosion"]

var sprite: SpriteAnimator
var health_component: HealthComponent
var hurtbox: HurtboxComponent
var attack_hitbox: HitboxComponent
var status_label: Label
var hp_bar_bg: ColorRect
var hp_bar: ColorRect

var state: AIState = AIState.PATROL
var spawn_position: Vector2 = Vector2.ZERO
var facing_dir: float = -1.0
var difficulty: float = 1.0
var _state_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _flash_timer: float = 0.0
var _patrol_min_x: float = 0.0
var _patrol_max_x: float = 0.0
var _anim_clock: float = 0.0
var _guard_timer: float = 0.0
var _guard_broken: bool = false


func _ready() -> void:
	add_to_group("enemies")
	if objective_tag != "":
		add_to_group(objective_tag)
	collision_layer = 4
	collision_mask = 1
	spawn_position = global_position
	_patrol_min_x = spawn_position.x - patrol_distance
	_patrol_max_x = spawn_position.x + patrol_distance
	_build_components()
	_on_ready_custom()


func _build_components() -> void:
	var feet := body_size.y * 0.5
	sprite = SpriteAnimator.new()
	sprite.name = "Sprite"
	add_child(sprite)
	sprite.setup(sheet_key, feet)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	col.shape = shape
	add_child(col)

	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	health_component.max_health = int(round(max_hp * difficulty))
	health_component.invulnerability_duration = 0.12
	add_child(health_component)

	hurtbox = HurtboxComponent.new()
	hurtbox.name = "HurtboxComponent"
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 40
	var hcol := CollisionShape2D.new()
	var hshape := RectangleShape2D.new()
	hshape.size = body_size + Vector2(4, 4)
	hcol.shape = hshape
	hurtbox.add_child(hcol)
	add_child(hurtbox)
	hurtbox.owner_actor = self
	hurtbox.health_component = health_component
	hurtbox.guard = _guard_hit

	attack_hitbox = HitboxComponent.new()
	attack_hitbox.name = "AttackHitbox"
	attack_hitbox.collision_layer = 16
	attack_hitbox.collision_mask = 2
	var acol := CollisionShape2D.new()
	var ashape := RectangleShape2D.new()
	ashape.size = Vector2(24, 20)
	acol.shape = ashape
	attack_hitbox.add_child(acol)
	add_child(attack_hitbox)
	attack_hitbox.owner_actor = self

	hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = Color(0.08, 0.07, 0.12, 0.85)
	hp_bar_bg.size = Vector2(26, 3)
	hp_bar_bg.position = Vector2(-13, -body_size.y * 0.5 - 14)
	hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bar_bg)
	hp_bar = ColorRect.new()
	hp_bar.color = Color(0.95, 0.3, 0.3)
	hp_bar.size = Vector2(26, 3)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar_bg.add_child(hp_bar)
	hp_bar_bg.visible = false

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color(1, 0.92, 0.3))
	status_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.1))
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.size = Vector2(70, 14)
	status_label.position = Vector2(-35, -body_size.y * 0.5 - 30)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	hurtbox.hit_received.connect(_on_hit_received)
	health_component.health_changed.connect(_on_health_changed)
	health_component.defeated.connect(_on_defeated)


## Applies level-specific overrides such as {"hp": 70, "patrol_distance": 120}.
func configure(params: Dictionary) -> void:
	for k in params.keys():
		if k in self:
			set(k, params[k])


# ------------------------------------------------------------------ virtual hooks
func _on_ready_custom() -> void:
	pass


## Return true when the subclass handled this frame's AI completely.
func _ai_custom(_delta: float, _player: PlayerController) -> bool:
	return false


func _begin_attack(_player: PlayerController) -> void:
	attack_hitbox.position = Vector2(facing_dir * 18.0, -2.0)
	attack_hitbox.activate(attack_damage, Vector2(150.0, -110.0), facing_dir, "enemy_strike", 0.25)


func _attack_tick(_delta: float) -> void:
	velocity.x = facing_dir * 30.0


func _anim_for_state() -> String:
	match state:
		AIState.PATROL, AIState.CHASE:
			if absf(velocity.x) > chase_speed * 0.8:
				return "run"
			return "walk" if absf(velocity.x) > 5.0 else "idle"
		AIState.TELEGRAPH:
			return "telegraph"
		AIState.ATTACK:
			return "attack"
		AIState.RECOVER:
			return "idle"
		AIState.HURT:
			return "hurt"
		AIState.SNARED:
			return "webbed"
		AIState.DEFEATED:
			return "ko"
	return "idle"


# ------------------------------------------------------------------ main loop
func reset_enemy() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	facing_dir = -1.0
	state = AIState.PATROL
	_state_timer = 0.0
	_cooldown_timer = 0.0
	visible = true
	modulate = Color(1, 1, 1, 1)
	collision_layer = 4
	collision_mask = 1
	hurtbox.monitoring = true
	hurtbox.monitorable = true
	attack_hitbox.deactivate()
	status_label.text = ""
	hp_bar_bg.visible = false
	health_component.reset_health()
	set_physics_process(true)


func apply_combat_hit(damage: int, knockback: Vector2, attack_type: String = "melee", stun_duration: float = 0.25) -> bool:
	return hurtbox.receive_hit(damage, knockback, attack_type, stun_duration)


func is_defeated() -> bool:
	return state == AIState.DEFEATED


func _physics_process(delta: float) -> void:
	if state == AIState.DEFEATED:
		if not flying and not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		move_and_slide()
		_update_visuals(delta)
		return
	_anim_clock += delta
	if _guard_timer > 0.0:
		_guard_timer -= delta
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	if not flying and not is_on_floor():
		velocity.y += GRAVITY * delta

	if global_position.y > kill_y and not health_component.is_dead:
		health_component.is_invulnerable = false
		health_component.take_damage(99999, Vector2.ZERO, "pitfall")
		return
	var player := get_active_player()
	if not _ai_custom(delta, player):
		_run_default_ai(delta, player)
	move_and_slide()
	_update_visuals(delta)


func _run_default_ai(delta: float, player: PlayerController) -> void:
	match state:
		AIState.PATROL:
			status_label.text = ""
			velocity.x = facing_dir * patrol_speed
			if global_position.x <= _patrol_min_x:
				facing_dir = 1.0
			elif global_position.x >= _patrol_max_x:
				facing_dir = -1.0
			if is_on_wall() or (not flying and is_on_floor() and not _ground_ahead()):
				facing_dir = -facing_dir
				velocity.x = facing_dir * patrol_speed
			if player != null and _can_see(player):
				state = AIState.CHASE
		AIState.CHASE:
			if player == null or global_position.distance_to(player.global_position) > detection_range * 1.4:
				state = AIState.PATROL
			else:
				_chase(player)
		AIState.TELEGRAPH:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_state_timer -= delta
			if player != null and _state_timer > telegraph_duration * 0.5:
				facing_dir = signf(player.global_position.x - global_position.x) if absf(player.global_position.x - global_position.x) > 2.0 else facing_dir
			if _state_timer <= 0.0:
				status_label.text = ""
				state = AIState.ATTACK
				_state_timer = attack_duration
				sprite.play("attack", true)
				_begin_attack(player)
		AIState.ATTACK:
			_attack_tick(delta)
			_state_timer -= delta
			if _state_timer <= 0.0:
				attack_hitbox.deactivate()
				_cooldown_timer = attack_cooldown / difficulty
				state = AIState.RECOVER
				_state_timer = recover_duration
		AIState.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			_state_timer -= delta
			if _state_timer <= 0.0:
				state = AIState.CHASE
		AIState.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 480.0 * delta)
			_state_timer -= delta
			if _state_timer <= 0.0:
				status_label.text = ""
				state = AIState.CHASE
		AIState.SNARED:
			velocity.x = move_toward(velocity.x, 0.0, 620.0 * delta)
			status_label.text = "WEBBED!"
			_state_timer -= delta
			if _state_timer <= 0.0:
				status_label.text = ""
				state = AIState.CHASE


func _can_see(player: PlayerController) -> bool:
	var d := player.global_position - global_position
	return d.length() <= detection_range and absf(d.y) < 80.0


func _chase(player: PlayerController) -> void:
	var dx := player.global_position.x - global_position.x
	if absf(dx) > 2.0:
		facing_dir = signf(dx)
	if absf(dx) <= attack_range and absf(player.global_position.y - global_position.y) < 34.0:
		velocity.x = 0.0
		if _cooldown_timer <= 0.0:
			start_telegraph()
	else:
		velocity.x = facing_dir * chase_speed
		# do not walk off rooftops while chasing
		if not flying and is_on_floor() and not _ground_ahead():
			velocity.x = 0.0


func start_telegraph() -> void:
	state = AIState.TELEGRAPH
	_state_timer = telegraph_duration / clampf(difficulty, 0.7, 1.5)
	status_label.text = "!"
	sprite.play("telegraph", true)


func _ground_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(facing_dir * (body_size.x * 0.5 + 6.0), 0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, body_size.y * 0.5 + 18.0), 1)
	return not space.intersect_ray(q).is_empty()


func get_active_player() -> PlayerController:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.size() > 0 and nodes[0] is PlayerController:
		var p := nodes[0] as PlayerController
		if p.current_state != PlayerController.State.DEFEATED:
			return p
	return null


# ------------------------------------------------------------------ guard & parry
## Hurtbox guard hook: enemies sometimes block light hits; heavy hits shatter the guard.
func _guard_hit(damage: int, _knockback: Vector2, attack_type: String, attacker: Node) -> int:
	if state == AIState.DEFEATED or not (attack_type in GUARDABLE or attack_type in GUARD_BREAKERS):
		return damage
	var guarding := _guard_timer > 0.0
	if not guarding and guard_chance > 0.0 and state in [AIState.CHASE, AIState.RECOVER, AIState.PATROL]:
		var facing_attacker := true
		if attacker is Node2D:
			facing_attacker = signf((attacker as Node2D).global_position.x - global_position.x) == facing_dir
		guarding = facing_attacker and randf() < guard_chance
	if not guarding:
		return damage
	if attack_type in GUARD_BREAKERS:
		_guard_timer = 0.0
		_guard_broken = true
		Fx.popup_text(get_parent(), global_position + Vector2(0, -body_size.y - 10), "GUARD BREAK!", Color(1, 0.55, 0.3), 10)
		Audio.play_sfx("heavy_hit", 0.9)
		return int(round(damage * 1.25))
	_guard_timer = 0.5
	velocity.x = -facing_dir * 55.0
	status_label.text = "BLOCK"
	Fx.burst(get_parent(), global_position + Vector2(facing_dir * 10.0, -6.0), Color(0.75, 0.85, 1.0), 6, 70.0, 0.0, 0.2)
	Audio.play_sfx("hit", 0.45)
	return -1


## Called by the player's guard when this enemy's strike is parried.
func apply_parry_stun(duration: float) -> void:
	if state == AIState.DEFEATED:
		return
	attack_hitbox.deactivate()
	_flash_timer = 0.15
	Fx.popup_text(get_parent(), global_position + Vector2(0, -body_size.y - 10), "STUNNED", Color(0.6, 0.9, 1.0), 10)
	if stagger_resist:
		_cooldown_timer = maxf(_cooldown_timer, duration)
		_on_parried(duration)
		return
	state = AIState.HURT
	_state_timer = duration
	velocity = Vector2(-facing_dir * 90.0, -40.0)
	sprite.play("hurt", true)


## Bosses override to enter their own vulnerable state.
func _on_parried(_duration: float) -> void:
	pass


# ------------------------------------------------------------------ damage & defeat
func _on_hit_received(damage: int, knockback: Vector2, attack_type: String, stun_duration: float) -> void:
	if state == AIState.DEFEATED:
		return
	_flash_timer = 0.12
	hp_bar_bg.visible = true
	_on_hit_custom(attack_type, damage)
	if state == AIState.DEFEATED or stagger_resist:
		return
	attack_hitbox.deactivate()
	velocity = knockback if not flying else knockback * 0.5
	if attack_type == "web_shot":
		state = AIState.SNARED
		_state_timer = maxf(0.85, stun_duration)
		sprite.play("webbed" if sprite.has_anim("webbed") else "hurt", true)
	else:
		state = AIState.HURT
		_state_timer = maxf(0.24, stun_duration) + (0.7 if _guard_broken else 0.0)
		_guard_broken = false
		status_label.text = ""
		sprite.play("hurt", true)


func _on_hit_custom(_attack_type: String, _damage: int) -> void:
	pass


func _on_health_changed(current_hp: int, max_hp_value: int) -> void:
	if hp_bar != null and max_hp_value > 0:
		hp_bar.size.x = 26.0 * (float(current_hp) / float(max_hp_value))


func _on_defeated() -> void:
	state = AIState.DEFEATED
	attack_hitbox.deactivate()
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	status_label.text = "KO!"
	hp_bar_bg.visible = false
	sprite.play("ko", true)
	Audio.play_sfx("heavy_hit", 0.8)
	Fx.burst(get_parent(), global_position, Color(1, 0.85, 0.4), 14, 120.0, 220.0, 0.4)
	enemy_defeated.emit(self)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(_finish_defeat)


func _finish_defeat() -> void:
	visible = false
	status_label.text = ""
	set_physics_process(false)


func _update_visuals(delta: float) -> void:
	if sprite == null:
		return
	sprite.flip_h = facing_dir < 0.0
	sprite.play(_anim_for_state())
	if _flash_timer > 0.0:
		_flash_timer -= delta
		sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
	elif state == AIState.TELEGRAPH:
		sprite.modulate = Color(1.0, 0.85 + 0.15 * sin(_anim_clock * 30.0), 0.6, 1.0)
	elif state == AIState.SNARED:
		sprite.modulate = Color(0.8, 0.95, 1.0, 1.0)
	elif _guard_timer > 0.0:
		sprite.modulate = Color(0.75, 0.85, 1.15, 1.0)
	else:
		sprite.modulate = Color(1, 1, 1, 1)
