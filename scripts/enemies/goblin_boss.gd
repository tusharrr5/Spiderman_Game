class_name GoblinBoss
extends BossBase
## The Goblin, riding an armoured glider.
## mode "ambush" (Chapter 3): a learnable fight that ends in a deliberate story defeat when he drops to 55% HP.
## mode "final"  (Chapter 5): three phases -
##   1: pumpkin-bomb tosses + swooping dives that crash him (VULNERABLE)
##   2: adds razor-bat spreads and summons bomb-drones once
##   3: enraged - bomb rain sweeps, faster cadence, triple bomb tosses
## Thrown crates knock him out of the air into a stunned, vulnerable state in any phase.

signal scripted_finale()

@export var mode: String = "final"
@export var hover_y: float = 120.0
@export var floor_y: float = 300.0

var _g: String = "intro"
var _gt: float = 0.0
var _attack_i: int = 0
var _swoop_target: Vector2 = Vector2.ZERO
var _warn_line: Line2D
var _summoned: bool = false
var _rain_dir: float = 1.0
var _rain_drops: int = 0
var _scripted: bool = false


func _init() -> void:
	sheet_key = "goblin"
	flying = true
	max_hp = 420
	body_size = Vector2(26, 34)
	display_name = "THE GOBLIN"
	attack_damage = 18
	vulnerable_bonus = 0.6


func _on_ready_custom() -> void:
	_warn_line = Line2D.new()
	_warn_line.width = 2.0
	_warn_line.default_color = Color(1.0, 0.25, 0.2, 0.6)
	_warn_line.visible = false
	_warn_line.top_level = true
	add_child(_warn_line)


func _anim_for_state() -> String:
	if state == AIState.DEFEATED:
		return "defeated"
	match _g:
		"tel_bomb", "tel_bats":
			return "telegraph"
		"throw":
			return "throw"
		"tel_swoop", "phase", "scripted", "intro":
			return "laugh"
		"swoop":
			return "dive"
		"stunned":
			return "stunned"
	return "hover"


func _set_g(s: String, t: float) -> void:
	_g = s
	_gt = t
	is_vulnerable = s == "stunned"
	sprite.play(_anim_for_state(), true)


func _ai_custom(delta: float, player: PlayerController) -> bool:
	state = AIState.CUSTOM
	_gt -= delta
	_warn_line.visible = _g == "tel_swoop"
	if not engaged:
		velocity = Vector2.ZERO
		if player != null and player.global_position.x >= arena_trigger_x:
			engage()
			Audio.play_sfx("goblin_laugh", 0.9)
			announce("THE GOBLIN ATTACKS!")
			_set_g("intro", 1.2)
		return true
	if _scripted:
		velocity = velocity.move_toward(Vector2(0, -20), 200.0 * delta)
		return true
	var speed_k := (1.0 + 0.18 * (phase - 1)) * clampf(difficulty, 0.8, 1.3)
	match _g:
		"intro", "phase":
			_hover_toward(player, delta, 0.6)
			if _gt <= 0.0:
				_set_g("hover", 0.9)
		"hover":
			_hover_toward(player, delta, 1.0)
			if _gt <= 0.0:
				_choose_attack(player)
		"tel_bomb":
			_hover_toward(player, delta, 0.3)
			if _gt <= 0.0:
				_throw_bombs(player)
				_set_g("throw", 0.35)
		"throw":
			if _gt <= 0.0:
				_set_g("hover", 1.1 / speed_k)
		"tel_swoop":
			velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
			_warn_line.clear_points()
			_warn_line.add_point(global_position)
			_warn_line.add_point(_swoop_target)
			if _gt <= 0.0:
				attack_hitbox.position = Vector2.ZERO
				attack_hitbox.activate(attack_damage, Vector2(230.0, -150.0), facing_dir, "goblin_swoop", 0.4)
				Audio.play_sfx("whoosh", 0.9)
				_set_g("swoop", 1.4)
		"swoop":
			var to := _swoop_target - global_position
			velocity = to.normalized() * 340.0 * speed_k
			facing_dir = signf(to.x) if absf(to.x) > 2.0 else facing_dir
			if to.length() < 12.0 or _gt <= 0.0:
				attack_hitbox.deactivate()
				velocity = Vector2.ZERO
				Fx.shake(4.0, 0.25)
				Audio.play_sfx("heavy_hit", 0.8)
				Fx.burst(get_parent(), global_position + Vector2(0, 16), Color(0.8, 0.8, 0.75), 16, 120.0, 100.0, 0.4)
				announce("GLIDER CRASHED - ATTACK NOW!")
				_set_g("stunned", 2.0 if phase == 1 else (1.7 if phase == 2 else 1.4))
		"stunned":
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			if _gt <= 0.0:
				announce("")
				_set_g("hover", 0.8)
		"tel_bats":
			_hover_toward(player, delta, 0.3)
			if _gt <= 0.0:
				_throw_bats(player)
				_set_g("throw", 0.35)
		"rain":
			velocity = Vector2(_rain_dir * 150.0 * speed_k, (hover_y - 30.0 - global_position.y) * 3.0)
			facing_dir = _rain_dir
			if _gt <= 0.0 and _rain_drops > 0:
				_rain_drops -= 1
				EnemyProjectile.spawn(get_parent(), "dropped_bomb", global_position + Vector2(0, 16), Vector2(0, 30), 14, self)
				_gt = 0.42
			if _rain_drops <= 0 or global_position.x <= arena_left_x + 10.0 or global_position.x >= arena_right_x - 10.0:
				_set_g("hover", 0.9)
	global_position.x = clampf(global_position.x, arena_left_x, arena_right_x)
	global_position.y = clampf(global_position.y, hover_y - 60.0, floor_y - 16.0)
	return true


func _hover_toward(player: PlayerController, delta: float, k: float) -> void:
	if player == null:
		velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
		return
	var side := -1.0 if global_position.x > player.global_position.x else 1.0
	var tx := clampf(player.global_position.x - side * 120.0, arena_left_x + 20.0, arena_right_x - 20.0)
	var ty := hover_y + sin(_anim_clock * 2.2) * 10.0
	var target := Vector2(tx, ty)
	velocity = velocity.move_toward((target - global_position) * 2.2 * k, 520.0 * delta)
	facing_dir = signf(player.global_position.x - global_position.x) if absf(player.global_position.x - global_position.x) > 4.0 else facing_dir


func _choose_attack(player: PlayerController) -> void:
	_attack_i += 1
	var pool: Array[String] = ["bomb", "swoop"]
	if phase >= 2:
		pool = ["bomb", "bats", "swoop"]
	if phase >= 3:
		pool = ["bomb", "rain", "bats", "swoop"]
	if mode == "ambush":
		pool = ["bomb", "swoop", "bomb"]
	var pick: String = pool[_attack_i % pool.size()]
	match pick:
		"bomb":
			status_label.text = "!"
			_set_g("tel_bomb", 0.6)
		"bats":
			status_label.text = "!"
			_set_g("tel_bats", 0.55)
		"swoop":
			status_label.text = "!!"
			Audio.play_sfx("goblin_laugh", 0.7)
			var px := player.global_position.x if player != null else (arena_left_x + arena_right_x) * 0.5
			_swoop_target = Vector2(px, floor_y - 20.0)
			_set_g("tel_swoop", 0.8 if phase < 3 else 0.6)
		"rain":
			_rain_dir = 1.0 if global_position.x < (arena_left_x + arena_right_x) * 0.5 else -1.0
			_rain_drops = 5
			announce("BOMB RAIN!")
			_set_g("rain", 0.3)


func _throw_bombs(player: PlayerController) -> void:
	status_label.text = ""
	if player == null:
		return
	var count := 3 if phase >= 3 else 1
	for i in range(count):
		var target := player.global_position + Vector2((i - (count - 1) * 0.5) * 46.0, 8.0)
		var t := 0.9
		var d := target - global_position
		var v := Vector2(d.x / t, (d.y - 0.5 * 420.0 * t * t) / t)
		EnemyProjectile.spawn(get_parent(), "bomb", global_position + Vector2(facing_dir * 10.0, -6.0), v, 16, self)
	Audio.play_sfx("whoosh", 0.6)


func _throw_bats(player: PlayerController) -> void:
	status_label.text = ""
	if player == null:
		return
	var n := 3 if phase < 3 else 5
	var base := (player.global_position - global_position).angle()
	for i in range(n):
		var a := base + (i - (n - 1) * 0.5) * 0.22
		EnemyProjectile.spawn(get_parent(), "bat", global_position + Vector2(facing_dir * 10.0, 0), Vector2.from_angle(a) * 170.0, 10, self)
	Audio.play_sfx("web_zip", 0.6)


func _on_hit_custom(attack_type: String, damage: int) -> void:
	if _scripted:
		return
	super._on_hit_custom(attack_type, damage)
	if health_component.is_dead:
		return
	if attack_type == "thrown_object" and _g != "stunned":
		attack_hitbox.deactivate()
		velocity = Vector2(0, 80)
		announce("KNOCKED OFF BALANCE!")
		_set_g("stunned", 1.5)
	var r := hp_ratio()
	if mode == "ambush":
		if r <= 0.55:
			_scripted = true
			attack_hitbox.deactivate()
			health_component.grant_invulnerability(999.0)
			_set_g("scripted", 99.0)
			Audio.play_sfx("goblin_laugh", 1.0)
			announce("")
			scripted_finale.emit()
		return
	var new_phase := 1
	if r <= 0.33:
		new_phase = 3
	elif r <= 0.66:
		new_phase = 2
	if new_phase > phase:
		phase = new_phase
		attack_hitbox.deactivate()
		health_component.grant_invulnerability(1.3)
		Fx.flash(Color(0.5, 1.0, 0.4, 0.35), 0.3)
		Audio.play_sfx("goblin_laugh", 1.0)
		announce("PHASE %d: %s" % [phase, "RAZOR BATS & DRONES!" if phase == 2 else "ENRAGED - BOMB RAIN!"])
		_set_g("phase", 1.3)
		if phase == 2 and not _summoned:
			_summoned = true
			_summon_drones()


func _summon_drones() -> void:
	for i in range(2):
		var d := DroneEnemy.new()
		d.difficulty = difficulty
		d.patrol_distance = 120.0
		d.position = Vector2(lerpf(arena_left_x + 60.0, arena_right_x - 60.0, float(i)), hover_y + 10.0)
		get_parent().add_child(d)
