class_name PlayerController
extends CharacterBody2D
## Spider-Man-inspired 2D Action-Platformer Player Controller (Phase 1 Prototype)
## Implements an explicit finite state machine covering:
## IDLE, RUNNING, JUMPING, FALLING, WALL_CLIMBING, CEILING_CRAWLING, WEB_SWINGING, ATTACKING, HURT, DEFEATED, DODGING

signal state_changed(new_state_name: String)
signal combo_updated(combo_count: int, move_label: String)
signal ability_cooldown_updated(super_jump_ready: bool, special_ready: bool, dark_suit_active: bool)
signal player_died()

enum State {
	IDLE,
	RUNNING,
	JUMPING,
	FALLING,
	WALL_CLIMBING,
	CEILING_CRAWLING,
	WEB_SWINGING,
	ATTACKING,
	HURT,
	DEFEATED,
	DODGING
}

# Movement & Physics Constants
const MAX_RUN_SPEED: float = 175.0
const GROUND_ACCEL: float = 1150.0
const GROUND_DECEL: float = 1350.0
const AIR_ACCEL: float = 820.0
const AIR_DECEL: float = 550.0
const GRAVITY: float = 690.0
const MAX_FALL_SPEED: float = 420.0

# Jump & Super Jump
const JUMP_VELOCITY: float = -285.0
const JUMP_CUT_MULTIPLIER: float = 0.48
const SUPER_JUMP_VELOCITY: float = -415.0
const SUPER_JUMP_COOLDOWN: float = 2.5

# Wall & Ceiling Crawling
const WALL_CLIMB_SPEED: float = 115.0
const CEILING_CRAWL_SPEED: float = 105.0
const CORNER_VAULT_BOOST: Vector2 = Vector2(95.0, -210.0)

# Web Traversal (Tether / Pendulum Swing)
const WEB_ATTACH_MAX_DIST: float = 185.0
const WEB_SWING_GRAVITY: float = 540.0
const WEB_SWING_PUMP_ACCEL: float = 240.0
const WEB_RELEASE_BOOST: Vector2 = Vector2(1.18, 1.05)

# Combat & Combo Timing
const COMBO_WINDOW: float = 0.55
const SPECIAL_COOLDOWN: float = 3.0
const OBJECT_GRAB_RADIUS: float = 84.0

# Dodge roll (Shift / DODGE button): brief invulnerable burst along the ground or through the air
const DODGE_SPEED: float = 265.0
const DODGE_DURATION: float = 0.32
const DODGE_COOLDOWN: float = 0.55

const SHEET_CLASSIC: String = "hero_classic"
const SHEET_DARK: String = "hero_dark"
const FEET_Y: float = 14.0
const MAX_WEB_SHOTS: int = 3

# Preloaded textures & scenes
var web_projectile_scene: PackedScene = preload("res://scenes/objects/web_projectile.tscn")

# Sound streams
var sfx_jump: AudioStream = preload("res://assets/audio/jump.wav")
var sfx_super_jump: AudioStream = preload("res://assets/audio/super_jump.wav")
var sfx_punch: AudioStream = preload("res://assets/audio/punch.wav")
var sfx_kick: AudioStream = preload("res://assets/audio/kick.wav")
var sfx_web: AudioStream = preload("res://assets/audio/web_shoot.wav")
var sfx_hurt: AudioStream = preload("res://assets/audio/hurt.wav")
var sfx_defeat: AudioStream = preload("res://assets/audio/defeat.wav")

# Child Node References
@onready var sprite: SpriteAnimator = $Sprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var melee_hitbox: HitboxComponent = $MeleeHitbox
@onready var web_line: Line2D = $WebLine
@onready var ability_particles: CPUParticles2D = $AbilityParticles
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

# Runtime State Machine Variables
var current_state: State = State.IDLE
var facing_dir: float = 1.0
var is_dark_suit: bool = false
var spawn_position: Vector2 = Vector2.ZERO

# Timers & Cooldowns
var _super_jump_cd: float = 0.0
var _special_cd: float = 0.0
var _attack_timer: float = 0.0
var _attack_hitbox_start: float = 0.0
var _attack_hitbox_end: float = 0.0
var _attack_elapsed: float = 0.0
var _combo_step: int = 0
var _combo_reset_timer: float = 0.0
var _hurt_timer: float = 0.0
var _anim_clock: float = 0.0
var _wall_detach_grace: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_cd: float = 0.0
var _air_dodge_used: bool = false
var _is_super_jump: bool = false
var _oneshot_anim: String = ""
var _oneshot_timer: float = 0.0
var _fall_peak_speed: float = 0.0
## Set by the campaign level while a cutscene / dialogue lock is active
var input_locked: bool = false

# Buffered One-Shot Action Flags & Edge-Detection State
# Captures both _input() hardware events AND Input.action_press() calls from on-screen buttons
var _buf_jump_pressed: bool = false
var _buf_jump_released: bool = false
var _buf_punch_pressed: bool = false
var _buf_kick_pressed: bool = false
var _buf_web_pressed: bool = false
var _buf_special_pressed: bool = false
var _buf_suit_pressed: bool = false
var _buf_down_pressed: bool = false
var _buf_dodge_pressed: bool = false
var _prev_action_held: Dictionary = {
	"jump": false,
	"attack_punch": false,
	"attack_kick": false,
	"web_action": false,
	"special_action": false,
	"suit_toggle": false,
	"climb_down": false,
	"dodge": false
}
## Last physics tick's pending one-shot buffers + held axis, read by InputDiagnosticsOverlay (stage S4)
var debug_last_input_snapshot: String = "none"

# Web Swing Tether State
var _swing_anchor: Vector2 = Vector2.ZERO
var _swing_length: float = 95.0
var _wall_normal_x: float = 0.0

# Pending Attack Configuration
var _pending_damage: int = 15
var _pending_kb: Vector2 = Vector2(150.0, -60.0)
var _pending_attack_id: String = "punch"
var _pending_stun: float = 0.25


func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	melee_hitbox.owner_actor = self
	hurtbox.owner_actor = self
	hurtbox.health_component = health_component

	health_component.damaged.connect(_on_damaged)
	health_component.defeated.connect(_on_defeated)
	health_component.invulnerability_changed.connect(_on_invulnerability_changed)
	melee_hitbox.hit_landed.connect(_on_melee_hit_landed)

	sprite.setup(SHEET_CLASSIC, FEET_Y)
	_apply_suit_palette()
	_emit_ability_state()


func _input(event: InputEvent) -> void:
	_capture_event_into_buffers(event)


func _capture_event_into_buffers(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("jump"):
		_buf_jump_pressed = true
	elif event.is_action_released("jump"):
		_buf_jump_released = true
	if event.is_action_pressed("attack_punch"):
		_buf_punch_pressed = true
	if event.is_action_pressed("attack_kick"):
		_buf_kick_pressed = true
	if event.is_action_pressed("web_action"):
		_buf_web_pressed = true
	if event.is_action_pressed("special_action"):
		_buf_special_pressed = true
	if event.is_action_pressed("suit_toggle"):
		_buf_suit_pressed = true
	if event.is_action_pressed("climb_down"):
		_buf_down_pressed = true
	if event.is_action_pressed("dodge"):
		_buf_dodge_pressed = true


func buffer_action_tap(action_name: String) -> void:
	## Called directly by on-screen touch/mouse buttons or Input.action_press() edge detection
	match action_name:
		"jump":
			_buf_jump_pressed = true
		"attack_punch":
			_buf_punch_pressed = true
		"attack_kick":
			_buf_kick_pressed = true
		"web_action":
			_buf_web_pressed = true
		"special_action":
			_buf_special_pressed = true
		"suit_toggle":
			_buf_suit_pressed = true
		"climb_down":
			_buf_down_pressed = true
		"dodge":
			_buf_dodge_pressed = true


func buffer_action_release(action_name: String) -> void:
	if action_name == "jump":
		_buf_jump_released = true


func _poll_action_edges() -> void:
	## Detects rising/falling edges on Input.is_action_pressed() so programmatic Input.action_press()
	## calls made during _process / GUI button_down (when Engine.is_in_physics_frame() is false)
	## reliably trigger discrete gameplay actions on the very next physics tick.
	for act_key in _prev_action_held.keys():
		var action_name: String = act_key as String
		var now_held: bool = Input.is_action_pressed(action_name)
		var was_held: bool = _prev_action_held[action_name] as bool
		if now_held and not was_held:
			buffer_action_tap(action_name)
		elif not now_held and was_held:
			buffer_action_release(action_name)
		_prev_action_held[action_name] = now_held


func _snapshot_input_for_diagnostics() -> void:
	var parts: PackedStringArray = []
	if _buf_jump_pressed: parts.append("jump")
	if _buf_jump_released: parts.append("jump_rel")
	if _buf_punch_pressed: parts.append("punch")
	if _buf_kick_pressed: parts.append("kick")
	if _buf_web_pressed: parts.append("web")
	if _buf_special_pressed: parts.append("special")
	if _buf_suit_pressed: parts.append("suit")
	if _buf_down_pressed: parts.append("down")
	var move_x := _move_axis()
	if parts.is_empty() and absf(move_x) < 0.05:
		return
	debug_last_input_snapshot = "tick%d [%s] axis=%.2f" % [Engine.get_physics_frames(), ",".join(parts), move_x]


func _clear_input_buffers() -> void:
	_buf_jump_pressed = false
	_buf_jump_released = false
	_buf_punch_pressed = false
	_buf_kick_pressed = false
	_buf_web_pressed = false
	_buf_special_pressed = false
	_buf_suit_pressed = false
	_buf_down_pressed = false
	_buf_dodge_pressed = false


func _move_axis() -> float:
	return 0.0 if input_locked else Input.get_axis("move_left", "move_right")


func _climb_axis() -> float:
	return 0.0 if input_locked else Input.get_axis("climb_up", "climb_down")


func _held(action: String) -> bool:
	return false if input_locked else Input.is_action_pressed(action)


func _is_dodge_just_pressed() -> bool:
	return _buf_dodge_pressed or Input.is_action_just_pressed("dodge")


func _is_jump_just_pressed() -> bool:
	return _buf_jump_pressed or Input.is_action_just_pressed("jump")


func _is_jump_just_released() -> bool:
	return _buf_jump_released or Input.is_action_just_released("jump")


func _is_punch_just_pressed() -> bool:
	return _buf_punch_pressed or Input.is_action_just_pressed("attack_punch")


func _is_kick_just_pressed() -> bool:
	return _buf_kick_pressed or Input.is_action_just_pressed("attack_kick")


func _is_web_just_pressed() -> bool:
	return _buf_web_pressed or Input.is_action_just_pressed("web_action")


func _is_special_just_pressed() -> bool:
	return _buf_special_pressed or Input.is_action_just_pressed("special_action")


func _is_down_just_pressed() -> bool:
	return _buf_down_pressed or Input.is_action_just_pressed("climb_down")


func reset_player(target_pos: Vector2) -> void:
	global_position = target_pos
	velocity = Vector2.ZERO
	facing_dir = 1.0
	sprite.flip_h = false
	sprite.modulate = Color(1, 1, 1, 1)
	_super_jump_cd = 0.0
	_special_cd = 0.0
	_combo_step = 0
	_combo_reset_timer = 0.0
	_hurt_timer = 0.0
	_wall_detach_grace = 0.0
	_dodge_timer = 0.0
	_dodge_cd = 0.0
	_air_dodge_used = false
	_is_super_jump = false
	_oneshot_anim = ""
	input_locked = false
	_clear_input_buffers()
	for k in _prev_action_held.keys():
		_prev_action_held[k] = false
	web_line.visible = false
	melee_hitbox.deactivate()
	health_component.reset_health()
	_transition_to(State.IDLE)
	_emit_ability_state()


func _physics_process(delta: float) -> void:
	_anim_clock += delta
	_poll_action_edges()
	_snapshot_input_for_diagnostics()
	if input_locked:
		_clear_input_buffers()
	_update_cooldowns(delta)
	if _oneshot_timer > 0.0:
		_oneshot_timer -= delta
		if _oneshot_timer <= 0.0:
			_oneshot_anim = ""
	var was_airborne := not is_on_floor()
	var prev_vy := velocity.y

	# Suit palette toggle ('C' or HUD button)
	if (_buf_suit_pressed or Input.is_action_just_pressed("suit_toggle")) and current_state != State.DEFEATED:
		_buf_suit_pressed = false
		toggle_suit_palette()

	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.RUNNING:
			_state_running(delta)
		State.JUMPING:
			_state_jumping(delta)
		State.FALLING:
			_state_falling(delta)
		State.WALL_CLIMBING:
			_state_wall_climbing(delta)
		State.CEILING_CRAWLING:
			_state_ceiling_crawling(delta)
		State.WEB_SWINGING:
			_state_web_swinging(delta)
		State.ATTACKING:
			_state_attacking(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEFEATED:
			_state_defeated(delta)
		State.DODGING:
			_state_dodging(delta)

	if is_on_floor():
		_air_dodge_used = false
		if was_airborne and prev_vy > 220.0 and current_state != State.DEFEATED:
			_on_hard_landing(prev_vy)
	_clear_input_buffers()
	_update_sprite_animation()


func _update_cooldowns(delta: float) -> void:
	var prev_sj := _super_jump_cd <= 0.0
	var prev_sp := _special_cd <= 0.0

	if _super_jump_cd > 0.0:
		_super_jump_cd = max(0.0, _super_jump_cd - delta)
	if _special_cd > 0.0:
		_special_cd = max(0.0, _special_cd - delta)
	if _wall_detach_grace > 0.0:
		_wall_detach_grace = max(0.0, _wall_detach_grace - delta)
	if _dodge_cd > 0.0:
		_dodge_cd = max(0.0, _dodge_cd - delta)

	if _combo_reset_timer > 0.0:
		_combo_reset_timer -= delta
		if _combo_reset_timer <= 0.0 and current_state != State.ATTACKING:
			_combo_step = 0
			combo_updated.emit(0, "")

	if (prev_sj != (_super_jump_cd <= 0.0)) or (prev_sp != (_special_cd <= 0.0)):
		_emit_ability_state()

	# Blink sprite gently while invulnerable
	if health_component.is_invulnerable and current_state != State.DEFEATED:
		sprite.modulate.a = 0.45 if int(_anim_clock * 18.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0


func toggle_suit_palette() -> void:
	is_dark_suit = not is_dark_suit
	_apply_suit_palette()
	_trigger_particles(Color(0.35, 0.45, 0.95) if is_dark_suit else Color(0.95, 0.25, 0.30))
	_emit_ability_state()


func _apply_suit_palette() -> void:
	if sprite != null and sprite.sheet_key != "":
		sprite.swap_sheet(SHEET_DARK if is_dark_suit else SHEET_CLASSIC)


func _emit_ability_state() -> void:
	ability_cooldown_updated.emit(_super_jump_cd <= 0.0, _special_cd <= 0.0, is_dark_suit)


# ==============================================================================
# STATE HANDLERS
# ==============================================================================

func _state_idle(delta: float) -> void:
	_apply_gravity(delta)
	var move_x := _move_axis()
	velocity.x = move_toward(velocity.x, 0.0, GROUND_DECEL * delta)

	if _check_combat_or_web_inputs():
		return
	if _try_jump_from_ground():
		return
	if not is_on_floor():
		_transition_to(State.FALLING)
		return
	if abs(move_x) > 0.05:
		_set_facing(move_x)
		_transition_to(State.RUNNING)
		return

	move_and_slide()
	if _try_attach_wall():
		return


func _state_running(delta: float) -> void:
	_apply_gravity(delta)
	var move_x := _move_axis()
	var suit_speed_mult := 1.08 if is_dark_suit else 1.0

	if abs(move_x) > 0.05:
		_set_facing(move_x)
		velocity.x = move_toward(velocity.x, move_x * MAX_RUN_SPEED * suit_speed_mult, GROUND_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DECEL * delta)

	if _check_combat_or_web_inputs():
		return
	if _try_jump_from_ground():
		return

	move_and_slide()

	if _try_attach_wall():
		return
	if not is_on_floor():
		_transition_to(State.FALLING)
	elif abs(velocity.x) < 5.0 and abs(move_x) <= 0.05:
		_transition_to(State.IDLE)


func _state_jumping(delta: float) -> void:
	_apply_gravity(delta)
	_handle_air_horizontal(delta)

	# Variable jump height when Jump is released early
	if _is_jump_just_released() and velocity.y < -80.0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	if _check_combat_or_web_inputs():
		return

	move_and_slide()

	if _try_attach_ceiling():
		return
	if _try_attach_wall():
		return
	if velocity.y >= 0.0:
		_transition_to(State.FALLING)
	elif is_on_floor():
		_transition_to(State.IDLE)


func _state_falling(delta: float) -> void:
	_apply_gravity(delta)
	_handle_air_horizontal(delta)

	if _check_combat_or_web_inputs():
		return

	move_and_slide()

	if is_on_floor():
		_transition_to(State.RUNNING if abs(velocity.x) > 15.0 else State.IDLE)
		return
	if _try_attach_ceiling():
		return
	if _try_attach_wall():
		return


func _state_wall_climbing(delta: float) -> void:
	var climb_axis := _climb_axis()
	var move_x := _move_axis()

	# Keep slight pressure toward the wall so move_and_slide maintains wall contact
	var into_wall_dir := -_wall_normal_x
	velocity.x = into_wall_dir * 35.0
	velocity.y = climb_axis * WALL_CLIMB_SPEED

	# Wall jump away or upward
	if _is_jump_just_pressed():
		_wall_detach_grace = 0.22
		var jump_dir: float = _wall_normal_x if absf(move_x) < 0.1 else signf(move_x)
		_set_facing(jump_dir)
		velocity = Vector2(jump_dir * MAX_RUN_SPEED * 0.95, JUMP_VELOCITY * 0.95)
		_play_sfx(sfx_jump)
		_transition_to(State.JUMPING)
		return

	# Explicit detach when pressing away from the wall without climbing up
	if move_x * _wall_normal_x > 0.5 and abs(climb_axis) < 0.1:
		_wall_detach_grace = 0.25
		_set_facing(move_x)
		velocity.x = move_x * 90.0
		_transition_to(State.FALLING)
		return

	move_and_slide()

	# Transition to ceiling crawl if hitting ceiling while climbing up
	if is_on_ceiling() and _held("climb_up"):
		_transition_to(State.CEILING_CRAWLING)
		return

	# Corner vault / top-out when reaching the top edge of a wall while holding climb_up
	if not is_on_wall():
		if climb_axis < -0.1:
			velocity = Vector2(into_wall_dir * CORNER_VAULT_BOOST.x, CORNER_VAULT_BOOST.y)
			_wall_detach_grace = 0.2
			_transition_to(State.JUMPING)
		else:
			_transition_to(State.FALLING)
		return

	if is_on_floor() and climb_axis > 0.1:
		_transition_to(State.IDLE)


func _state_ceiling_crawling(delta: float) -> void:
	var move_x := _move_axis()
	velocity.x = move_x * CEILING_CRAWL_SPEED
	# Upward adhesion force keeps character flush with the ceiling
	velocity.y = -45.0

	if abs(move_x) > 0.05:
		_set_facing(move_x)

	# Explicit detachment via Down ('S'/Down) or Jump ('Space')
	if _is_down_just_pressed() or _is_jump_just_pressed():
		velocity.y = 45.0
		_wall_detach_grace = 0.25
		_transition_to(State.FALLING)
		return

	move_and_slide()

	if not is_on_ceiling():
		velocity.y = 20.0
		_transition_to(State.FALLING)


func _state_web_swinging(delta: float) -> void:
	var to_player := global_position - _swing_anchor
	var dist := to_player.length()
	if dist < 8.0:
		dist = 8.0
		to_player = Vector2(0, 8.0)

	var radial_dir := to_player / dist
	var tangent := Vector2(radial_dir.y, -radial_dir.x)
	if tangent.y > 0.0:
		tangent = -tangent

	# Apply pendulum gravity + player directional pump
	velocity.y += WEB_SWING_GRAVITY * delta
	var move_x := _move_axis()
	velocity.x += move_x * WEB_SWING_PUMP_ACCEL * delta
	if abs(move_x) > 0.1:
		_set_facing(move_x)
	elif abs(velocity.x) > 10.0:
		_set_facing(sign(velocity.x))

	# Constrain distance to tether length and remove outward radial velocity
	if dist >= _swing_length:
		global_position = _swing_anchor + radial_dir * _swing_length
		var radial_vel := velocity.dot(radial_dir)
		if radial_vel > 0.0:
			velocity -= radial_dir * radial_vel

	# Update visible web line from player hand to overhead anchor
	web_line.visible = true
	web_line.clear_points()
	web_line.add_point(Vector2(facing_dir * 6.0, -8.0))
	web_line.add_point(to_local(_swing_anchor))

	# Release web and preserve momentum on Jump or second Web press
	if _is_jump_just_pressed() or _is_web_just_pressed():
		web_line.visible = false
		velocity = Vector2(velocity.x * WEB_RELEASE_BOOST.x, min(velocity.y * WEB_RELEASE_BOOST.y, -225.0))
		_play_sfx(sfx_jump)
		_transition_to(State.JUMPING)
		return

	move_and_slide()

	if is_on_floor() or is_on_wall() or is_on_ceiling():
		web_line.visible = false
		_transition_to(State.IDLE if is_on_floor() else State.FALLING)


func _state_attacking(delta: float) -> void:
	_apply_gravity(delta)
	var move_x := _move_axis()
	if absf(move_x) > 0.05:
		_set_facing(move_x)
		velocity.x = move_toward(velocity.x, move_x * MAX_RUN_SPEED * 0.55, GROUND_ACCEL * 0.6 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_DECEL * 0.75 * delta)
	_attack_elapsed += delta

	# Activate hitbox strictly within active window
	if _attack_elapsed >= _attack_hitbox_start and _attack_elapsed <= _attack_hitbox_end:
		if not melee_hitbox.is_active:
			melee_hitbox.position = Vector2(facing_dir * 16.0, -2.0)
			var suit_bonus := 4 if is_dark_suit else 0
			melee_hitbox.activate(_pending_damage + suit_bonus, _pending_kb, facing_dir, _pending_attack_id, _pending_stun)
	else:
		if melee_hitbox.is_active:
			melee_hitbox.deactivate()

	# Allow queuing next chained combo step during the back half of current attack
	if _attack_elapsed >= _attack_hitbox_start:
		if _is_punch_just_pressed() and _combo_step == 1:
			_start_melee_attack(2)
			return
		elif (_is_kick_just_pressed() or _is_punch_just_pressed()) and _combo_step == 2:
			_start_melee_attack(3)
			return

	move_and_slide()

	if _attack_elapsed >= _attack_timer:
		melee_hitbox.deactivate()
		_transition_to(State.IDLE if is_on_floor() else State.FALLING)


func _state_hurt(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 520.0 * delta)
	_hurt_timer -= delta
	move_and_slide()
	if _hurt_timer <= 0.0:
		_transition_to(State.IDLE if is_on_floor() else State.FALLING)


func _state_defeated(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 650.0 * delta)
	move_and_slide()


# ==============================================================================
# ABILITY & INPUT HELPERS
# ==============================================================================

func _try_jump_from_ground() -> bool:
	if not is_on_floor():
		return false
	if _is_jump_just_pressed():
		_buf_jump_pressed = false
		# Super Jump when holding Up ('W'/Up Arrow) + Jump while off cooldown
		if _held("climb_up") and _super_jump_cd <= 0.0:
			velocity.y = SUPER_JUMP_VELOCITY
			_is_super_jump = true
			_super_jump_cd = SUPER_JUMP_COOLDOWN
			_play_sfx(sfx_super_jump)
			_trigger_particles(Color(0.35, 0.85, 1.0, 1.0))
			_emit_ability_state()
			combo_updated.emit(0, "SUPER JUMP!")
		else:
			velocity.y = JUMP_VELOCITY
			_is_super_jump = false
			_play_sfx(sfx_jump)
		_transition_to(State.JUMPING)
		return true
	return false


func _try_attach_wall() -> bool:
	if _wall_detach_grace > 0.0 or not is_on_wall():
		return false
	var move_x := _move_axis()
	var wall_normal := get_wall_normal()
	var pressing_into_wall := (move_x * wall_normal.x) < -0.25
	if _held("climb_up") or pressing_into_wall:
		_wall_normal_x = 1.0 if wall_normal.x >= 0.0 else -1.0
		_set_facing(-_wall_normal_x)
		velocity = Vector2.ZERO
		_transition_to(State.WALL_CLIMBING)
		return true
	return false


func _try_attach_ceiling() -> bool:
	if _wall_detach_grace > 0.0 or not is_on_ceiling():
		return false
	if _held("climb_up"):
		velocity = Vector2.ZERO
		_transition_to(State.CEILING_CRAWLING)
		return true
	return false


func _check_combat_or_web_inputs() -> bool:
	# 0. Dodge roll ('Shift')
	if _is_dodge_just_pressed() and _try_start_dodge():
		return true

	# 1. Punch / Chained Combo ('J')
	if _is_punch_just_pressed():
		var next_step := 1
		if _combo_reset_timer > 0.0 and _combo_step in [1, 2]:
			next_step = _combo_step + 1
		_start_melee_attack(next_step)
		return true

	# 2. Kick ('H')
	if _is_kick_just_pressed():
		var kick_step := 3 if (_combo_reset_timer > 0.0 and _combo_step >= 1) else 0
		_start_melee_attack(kick_step)
		return true

	# 3. Web Action ('K'): Swing if airborne or holding Up near an overhead anchor; otherwise fire Web Projectile
	if _is_web_just_pressed():
		if (not is_on_floor() or _held("climb_up")) and _try_start_web_swing():
			return true
		_fire_web_projectile()
		return true

	# 4. Special Move or Object Throw ('L')
	if _is_special_just_pressed():
		if _try_throw_nearby_object():
			return true
		if _special_cd <= 0.0:
			_start_special_web_slam()
			return true

	return false


func _start_melee_attack(step: int) -> void:
	_combo_step = step
	_combo_reset_timer = COMBO_WINDOW
	_attack_elapsed = 0.0
	_buf_punch_pressed = false
	_buf_kick_pressed = false

	if step == 1:
		_pending_damage = 14
		_pending_kb = Vector2(125.0, -45.0)
		_pending_attack_id = "jab_1"
		_pending_stun = 0.22
		_attack_timer = 0.22
		_attack_hitbox_start = 0.04
		_attack_hitbox_end = 0.16
		velocity.x = facing_dir * 75.0
		_play_sfx(sfx_punch)
		combo_updated.emit(1, "JAB!")
	elif step == 2:
		_pending_damage = 18
		_pending_kb = Vector2(150.0, -65.0)
		_pending_attack_id = "cross_2"
		_pending_stun = 0.28
		_attack_timer = 0.25
		_attack_hitbox_start = 0.05
		_attack_hitbox_end = 0.18
		velocity.x = facing_dir * 95.0
		_play_sfx(sfx_punch)
		combo_updated.emit(2, "CROSS COMBO!")
	elif step == 3:
		_pending_damage = 26
		_pending_kb = Vector2(240.0, -135.0)
		_pending_attack_id = "spider_finisher"
		_pending_stun = 0.45
		_attack_timer = 0.32
		_attack_hitbox_start = 0.06
		_attack_hitbox_end = 0.24
		velocity.x = facing_dir * 135.0
		_play_sfx(sfx_kick)
		_trigger_particles(Color(1.0, 0.85, 0.25, 1.0))
		combo_updated.emit(3, "3-HIT FINISHER!")
		_combo_step = 0
	else:
		# Standalone Acrobatic Kick ('H')
		_pending_damage = 20
		_pending_kb = Vector2(195.0, -90.0)
		_pending_attack_id = "kick"
		_pending_stun = 0.32
		_attack_timer = 0.28
		_attack_hitbox_start = 0.05
		_attack_hitbox_end = 0.20
		velocity.x = facing_dir * 105.0
		_play_sfx(sfx_kick)
		combo_updated.emit(1, "ROUNDHOUSE KICK!")

	sprite.play(_ATTACK_ANIMS.get(_pending_attack_id, "jab"), true)
	_transition_to(State.ATTACKING)


func _start_special_web_slam() -> void:
	_special_cd = SPECIAL_COOLDOWN
	_emit_ability_state()
	_combo_step = 0
	_attack_elapsed = 0.0
	_buf_special_pressed = false
	_pending_damage = 34
	_pending_kb = Vector2(280.0, -160.0)
	_pending_attack_id = "web_slam_special"
	_pending_stun = 0.65
	_attack_timer = 0.38
	_attack_hitbox_start = 0.06
	_attack_hitbox_end = 0.30
	velocity = Vector2(facing_dir * 210.0, -110.0)
	_play_sfx(sfx_web)
	_trigger_particles(Color(0.9, 0.96, 1.0, 1.0))
	combo_updated.emit(3, "WEB IMPACT SLAM!")
	sprite.play("slam", true)
	Fx.shake(3.0, 0.2)
	_transition_to(State.ATTACKING)


func _fire_web_projectile() -> void:
	_buf_web_pressed = false
	if web_projectile_scene == null or get_parent() == null:
		return
	# Cap simultaneous web shots so mashing K can never flood the scene
	var active := 0
	for p in get_tree().get_nodes_in_group("projectiles"):
		if p is WebProjectile and (p as WebProjectile).shooter == self:
			active += 1
	if active >= MAX_WEB_SHOTS:
		return
	_set_oneshot("web_shoot", 0.22)
	var proj := web_projectile_scene.instantiate() as WebProjectile
	get_parent().add_child(proj)
	proj.setup(global_position + Vector2(facing_dir * 16.0, -4.0), facing_dir, self)
	_play_sfx(sfx_web)
	combo_updated.emit(1, "WEB SHOT!")


func _try_throw_nearby_object() -> bool:
	var best_obj: ThrowableObject = null
	var best_dist: float = OBJECT_GRAB_RADIUS
	for node in get_tree().get_nodes_in_group("throwables"):
		if node is ThrowableObject:
			var tobj := node as ThrowableObject
			if not tobj.is_thrown and not tobj.is_consumed:
				var d := global_position.distance_to(tobj.global_position)
				if d <= best_dist:
					best_dist = d
					best_obj = tobj
	if best_obj != null:
		_buf_special_pressed = false
		best_obj.launch(facing_dir, self)
		_set_oneshot("throw", 0.3)
		_play_sfx(sfx_web)
		_trigger_particles(Color(0.95, 0.80, 0.45, 1.0))
		combo_updated.emit(2, "WEB OBJECT THROW!")
		return true
	return false


func _try_start_web_swing() -> bool:
	var best_anchor: Node2D = null
	var best_dist: float = WEB_ATTACH_MAX_DIST
	for node in get_tree().get_nodes_in_group("web_anchors"):
		if node is Node2D:
			var anchor := node as Node2D
			# Anchor must be above the player and within attach distance
			if anchor.global_position.y < global_position.y - 18.0:
				var d := global_position.distance_to(anchor.global_position)
				if d <= best_dist:
					best_dist = d
					best_anchor = anchor
	if best_anchor != null:
		_buf_web_pressed = false
		_swing_anchor = best_anchor.global_position
		_swing_length = clamp(best_dist, 48.0, 145.0)
		if is_on_floor():
			global_position.y -= 8.0
			velocity.y = -120.0
		velocity.x += facing_dir * 85.0
		_play_sfx(sfx_web)
		combo_updated.emit(0, "WEB SWING!")
		_transition_to(State.WEB_SWINGING)
		return true
	return false


func _handle_air_horizontal(delta: float) -> void:
	var move_x := _move_axis()
	if abs(move_x) > 0.05:
		_set_facing(move_x)
		velocity.x = move_toward(velocity.x, move_x * MAX_RUN_SPEED, AIR_ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, AIR_DECEL * delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = min(MAX_FALL_SPEED, velocity.y + GRAVITY * delta)


func _set_facing(dir: float) -> void:
	if abs(dir) > 0.01:
		facing_dir = -1.0 if dir < 0.0 else 1.0
		if sprite != null:
			sprite.flip_h = facing_dir < 0.0


func _transition_to(new_state: State) -> void:
	if current_state == new_state:
		return
	if new_state != State.JUMPING:
		_is_super_jump = false
	if current_state == State.WEB_SWINGING:
		web_line.visible = false
	if current_state == State.ATTACKING:
		melee_hitbox.deactivate()
	current_state = new_state
	state_changed.emit(State.keys()[current_state])


# ==============================================================================
# DAMAGE, HIT FEEDBACK & ANIMATION
# ==============================================================================

func apply_combat_hit(damage: int, knockback: Vector2, attack_type: String = "enemy_attack", _stun: float = 0.25) -> bool:
	return health_component.take_damage(damage, knockback, attack_type)


func _on_damaged(_amount: int, knockback: Vector2, _source_type: String) -> void:
	if current_state == State.DEFEATED:
		return
	web_line.visible = false
	melee_hitbox.deactivate()
	velocity = knockback
	if velocity.y > -60.0:
		velocity.y = -140.0
	_hurt_timer = 0.26
	_play_sfx(sfx_hurt)
	sprite.play("hurt", true)
	Fx.shake(3.0, 0.15)
	Fx.flash(Color(1, 0.2, 0.2, 0.25), 0.2)
	_trigger_particles(Color(1.0, 0.3, 0.3, 1.0))
	_transition_to(State.HURT)


func _on_defeated() -> void:
	web_line.visible = false
	melee_hitbox.deactivate()
	velocity = Vector2(-facing_dir * 90.0, -160.0)
	_play_sfx(sfx_defeat)
	_transition_to(State.DEFEATED)
	player_died.emit()


func _on_invulnerability_changed(is_invuln: bool) -> void:
	if not is_invuln and sprite != null:
		sprite.modulate.a = 1.0


func _on_melee_hit_landed(target: Node, damage_dealt: int, attack_id: String) -> void:
	_trigger_particles(Color(1.0, 0.92, 0.35, 1.0))
	var heavy := attack_id in ["spider_finisher", "web_slam_special", "kick"]
	Fx.hitstop(0.075 if heavy else 0.045)
	Fx.shake(3.5 if heavy else 2.0, 0.14)
	Audio.play_sfx("heavy_hit" if heavy else "hit", 0.9)
	if target is Node2D:
		Fx.burst(get_parent(), (target as Node2D).global_position + Vector2(0, -6), Color(1.0, 0.95, 0.6), 10, 110.0, 160.0, 0.25)
		Fx.popup_text(get_parent(), (target as Node2D).global_position + Vector2(0, -26), str(damage_dealt), Color(1, 0.92, 0.4), 9)


func _trigger_particles(color: Color) -> void:
	if ability_particles != null:
		ability_particles.color = color
		ability_particles.restart()
		ability_particles.emitting = true


func _play_sfx(stream: AudioStream) -> void:
	if stream != null:
		Audio.play_sfx(stream.resource_path, 0.85)


func _set_oneshot(anim: String, duration: float) -> void:
	_oneshot_anim = anim
	_oneshot_timer = duration
	if sprite != null:
		sprite.play(anim, true)


func _try_start_dodge() -> bool:
	if _dodge_cd > 0.0 or current_state == State.DEFEATED:
		return false
	if not is_on_floor():
		if _air_dodge_used:
			return false
		_air_dodge_used = true
	_buf_dodge_pressed = false
	var dir := _move_axis()
	if absf(dir) > 0.1:
		_set_facing(dir)
	_dodge_timer = DODGE_DURATION
	_dodge_cd = DODGE_COOLDOWN
	velocity.x = facing_dir * DODGE_SPEED
	if not is_on_floor():
		velocity.y = minf(velocity.y, -60.0)
	health_component.grant_invulnerability(DODGE_DURATION + 0.05)
	Audio.play_sfx("dodge", 0.8)
	_transition_to(State.DODGING)
	return true


func _state_dodging(delta: float) -> void:
	_apply_gravity(delta)
	_dodge_timer -= delta
	velocity.x = move_toward(velocity.x, facing_dir * DODGE_SPEED * 0.35, 520.0 * delta)
	move_and_slide()
	if _dodge_timer <= 0.0:
		_transition_to(State.IDLE if is_on_floor() else State.FALLING)


func _on_hard_landing(impact_speed: float) -> void:
	Fx.burst(get_parent(), global_position + Vector2(0, FEET_Y), Color(0.85, 0.82, 0.78, 0.8), 8, 70.0, 60.0, 0.3)
	Audio.play_sfx("land", clampf(impact_speed / 420.0, 0.3, 0.9))
	if impact_speed > 380.0:
		Fx.shake(2.0, 0.1)
	if current_state == State.IDLE:
		_set_oneshot("land", 0.12)


const _ATTACK_ANIMS: Dictionary = {
	"jab_1": "jab", "cross_2": "cross", "spider_finisher": "finisher", "kick": "kick", "web_slam_special": "slam"
}


func _update_sprite_animation() -> void:
	if sprite == null:
		return
	sprite.speed_scale = 1.0
	sprite.offset = Vector2.ZERO
	var anim := "idle"
	match current_state:
		State.IDLE:
			anim = "idle"
		State.RUNNING:
			anim = "run"
			sprite.speed_scale = clampf(absf(velocity.x) / MAX_RUN_SPEED, 0.45, 1.25)
		State.JUMPING:
			anim = "super_jump" if _is_super_jump else "jump"
		State.FALLING:
			anim = "fall"
		State.WALL_CLIMBING:
			anim = "wall_climb" if absf(velocity.y) > 5.0 else "wall_idle"
		State.CEILING_CRAWLING:
			anim = "ceiling_crawl"
			sprite.speed_scale = 1.0 if absf(velocity.x) > 5.0 else 0.0
			sprite.offset = Vector2(0, 30)
		State.WEB_SWINGING:
			anim = "swing"
		State.ATTACKING:
			anim = _ATTACK_ANIMS.get(_pending_attack_id, "jab")
		State.HURT:
			anim = "hurt"
		State.DEFEATED:
			anim = "defeated"
		State.DODGING:
			anim = "dodge"
	# Short overlay actions (web shot, throw, landing) only replace calm grounded/air poses
	if _oneshot_anim != "" and current_state in [State.IDLE, State.RUNNING, State.JUMPING, State.FALLING]:
		anim = _oneshot_anim
	sprite.play(anim)
