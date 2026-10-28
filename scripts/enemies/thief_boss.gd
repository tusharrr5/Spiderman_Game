class_name ThiefBoss
extends BossBase
## Chapter 2 thief. FLEE phase: sprints along a scripted rooftop route (jumping marked gaps), taunting when the
## player falls behind. When cornered at the route end he fights: telegraphed energy shots from the stolen device
## and dash kicks that leave him exhausted (vulnerable) afterwards.

signal cornered()

## Route points: [{"x": 400.0, "jump": -330.0}, ...] - jump is applied when he reaches x while grounded.
var route: Array = []
@export var flee_speed: float = 150.0

var _mode: String = "flee"          # flee, taunt, fight
var _route_i: int = 0
var _fstate: String = "position"
var _ftimer: float = 0.0
var _cycle: int = 0


func _init() -> void:
	sheet_key = "thief"
	max_hp = 170
	body_size = Vector2(16, 30)
	display_name = "THE THIEF"
	attack_damage = 14
	vulnerable_bonus = 0.6


func _anim_for_state() -> String:
	if state == AIState.DEFEATED:
		return "ko"
	if state == AIState.SNARED:
		return "webbed"
	if _mode == "taunt":
		return "taunt"
	if _mode == "flee":
		if not is_on_floor():
			return "jump"
		return "run" if absf(velocity.x) > 10.0 else "idle"
	match _fstate:
		"tel_shot":
			return "telegraph"
		"shot":
			return "attack"
		"tel_dash":
			return "telegraph"
		"dash":
			return "run"
		"exhausted":
			return "hurt"
		"position":
			return "walk" if absf(velocity.x) > 10.0 else "idle"
	return "idle"


func _ai_custom(delta: float, player: PlayerController) -> bool:
	if state == AIState.SNARED:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		_state_timer -= delta
		status_label.text = "WEBBED!"
		if _state_timer <= 0.0:
			status_label.text = ""
			state = AIState.CUSTOM
		return true
	state = AIState.CUSTOM
	match _mode:
		"flee", "taunt":
			_flee(delta, player)
		"fight":
			_fight(delta, player)
	return true


func _flee(_delta: float, player: PlayerController) -> void:
	facing_dir = 1.0
	if player != null and player.global_position.x < global_position.x - 280.0 and is_on_floor():
		_mode = "taunt"
		velocity.x = 0.0
		status_label.text = "Too slow!"
		facing_dir = -1.0
		return
	if _mode == "taunt":
		velocity.x = 0.0
		facing_dir = -1.0
		if player == null or player.global_position.x > global_position.x - 190.0:
			_mode = "flee"
			status_label.text = ""
		return
	var speed := flee_speed
	if player != null and absf(player.global_position.x - global_position.x) < 60.0:
		speed *= 1.35         # burst away when the hero closes in
	velocity.x = speed
	if _route_i < route.size():
		var pt: Dictionary = route[_route_i]
		if global_position.x >= float(pt["x"]):
			if pt.has("jump") and is_on_floor():
				velocity.y = float(pt["jump"])
			_route_i += 1
	if global_position.x >= arena_left_x and _route_i >= route.size():
		_mode = "fight"
		_fstate = "position"
		_ftimer = 0.8
		velocity = Vector2.ZERO
		engage()
		announce("CORNERED! BREAK HIS GUARD AFTER A DASH")
		cornered.emit()


func _fight(delta: float, player: PlayerController) -> void:
	is_vulnerable = _fstate == "exhausted"
	_ftimer -= delta
	match _fstate:
		"position":
			status_label.text = ""
			if player != null:
				var dx := player.global_position.x - global_position.x
				facing_dir = signf(dx) if absf(dx) > 2.0 else facing_dir
				if absf(dx) < 90.0:
					velocity.x = -facing_dir * 95.0
				elif absf(dx) > 170.0:
					velocity.x = facing_dir * 80.0
				else:
					velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if _ftimer <= 0.0:
				_cycle += 1
				if _cycle % 3 == 0:
					_set_f("tel_dash", 0.6)
					status_label.text = "!!"
					Audio.play_sfx("boss_warn", 0.6)
				else:
					_set_f("tel_shot", 0.5)
					status_label.text = "!"
		"tel_shot":
			velocity.x = 0.0
			if _ftimer <= 0.0:
				var target_dir := facing_dir
				EnemyProjectile.spawn(get_parent(), "energy", global_position + Vector2(facing_dir * 14.0, -6.0),
					Vector2(target_dir * 250.0, 0.0), 12, self)
				Audio.play_sfx("energy_shot", 0.6)
				_set_f("shot", 0.3)
		"shot":
			if _ftimer <= 0.0:
				_set_f("position", 0.9 / clampf(difficulty, 0.8, 1.4))
		"tel_dash":
			velocity.x = 0.0
			if player != null:
				facing_dir = signf(player.global_position.x - global_position.x) if absf(player.global_position.x - global_position.x) > 2.0 else facing_dir
			if _ftimer <= 0.0:
				status_label.text = ""
				attack_hitbox.position = Vector2(facing_dir * 14.0, 0.0)
				attack_hitbox.activate(attack_damage, Vector2(200.0, -120.0), facing_dir, "thief_dash", 0.3)
				_set_f("dash", 0.5)
		"dash":
			velocity.x = facing_dir * 290.0
			if _ftimer <= 0.0 or is_on_wall() or global_position.x <= arena_left_x or global_position.x >= arena_right_x:
				attack_hitbox.deactivate()
				velocity.x = 0.0
				announce("EXHAUSTED - STRIKE NOW!")
				status_label.text = "OPEN!"
				_set_f("exhausted", 1.5)
		"exhausted":
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _ftimer <= 0.0:
				announce("")
				status_label.text = ""
				_set_f("position", 0.6)
	global_position.x = clampf(global_position.x, arena_left_x - 40.0, arena_right_x)


func _set_f(s: String, t: float) -> void:
	_fstate = s
	_ftimer = t
	sprite.play(_anim_for_state(), true)


func _on_hit_custom(attack_type: String, damage: int) -> void:
	if _mode != "fight":
		# can be webbed during the chase to slow him down, but he can't be finished before he's cornered
		hp_bar_bg.visible = false
		if attack_type == "web_shot":
			state = AIState.SNARED
			_state_timer = 1.2
		if health_component.current_health < int(health_component.max_health * 0.6):
			health_component.current_health = int(health_component.max_health * 0.6)
		return
	super._on_hit_custom(attack_type, damage)
	if attack_type == "web_shot" and _fstate == "position":
		state = AIState.SNARED
		_state_timer = 0.8
