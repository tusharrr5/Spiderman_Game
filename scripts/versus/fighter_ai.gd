class_name FighterAI
extends RefCounted
## Bot brain for versus fighters. It drives a PlayerController through the same action buffers and held
## actions a human uses (move, block, jump, punch/kick/heavy, web, dodge, specials, focus charge), so the
## bot has exactly the player's moveset. Difficulty changes reaction time, guard/parry habits, aggression,
## combo length, special usage and damage output.

const LEVELS: Dictionary = {
	"easy": {"rest": 1.4, "react": 0.5, "block": 0.12, "parry": 0.0, "aggr": 0.35, "combo": 1, "special": 0.2, "dodge": 0.05, "dmg": 0.7, "think": 0.4, "guard": 0.0},
	"moderate": {"rest": 0.9, "react": 0.3, "block": 0.35, "parry": 0.12, "aggr": 0.55, "combo": 2, "special": 0.55, "dodge": 0.12, "dmg": 0.9, "think": 0.24, "guard": 0.1},
	"difficult": {"rest": 0.55, "react": 0.18, "block": 0.6, "parry": 0.4, "aggr": 0.72, "combo": 3, "special": 0.85, "dodge": 0.22, "dmg": 1.05, "think": 0.14, "guard": 0.25},
	"more_difficult": {"rest": 0.35, "react": 0.1, "block": 0.82, "parry": 0.68, "aggr": 0.88, "combo": 4, "special": 1.0, "dodge": 0.32, "dmg": 1.2, "think": 0.08, "guard": 0.4},
}
const NAMES: Dictionary = {"easy": "EASY", "moderate": "MODERATE", "difficult": "DIFFICULT", "more_difficult": "MORE DIFFICULT"}
const MELEE_RANGE: float = 30.0

var me: PlayerController
var level: String = "moderate"
var p: Dictionary
## Read by PlayerController each tick
var move_axis: float = 0.0
var climb_axis: float = 0.0
var _held: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _think_t: float = 0.0
var _plan: String = "approach"
var _plan_t: float = 0.0
var _combo_left: int = 0
var _press_t: float = 0.0
var _hold_t: Dictionary = {}           # action -> seconds left to keep holding
var _react_t: float = -1.0
var _react_kind: String = ""
var _last_target_state: int = -1
var _last_target_elapsed: float = 0.0
## Telemetry for tests / tuning
var stats: Dictionary = {"blocks_started": 0, "parry_attempts": 0, "attacks": 0, "specials": 0, "dodges": 0}


func _init(fighter: PlayerController, difficulty: String, seed_value: int = 0) -> void:
	me = fighter
	level = difficulty if LEVELS.has(difficulty) else "moderate"
	p = LEVELS[level]
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func is_held(action: String) -> bool:
	return bool(_held.get(action, false))


func _hold(action: String, seconds: float) -> void:
	_held[action] = true
	_hold_t[action] = maxf(float(_hold_t.get(action, 0.0)), seconds)


func _release(action: String) -> void:
	_held[action] = false
	_hold_t.erase(action)


func _tap(action: String) -> void:
	me.buffer_action_tap(action)


func target() -> PlayerController:
	var best: PlayerController = null
	var best_d := INF
	for n in me.foes():
		var f := n as PlayerController
		if f == null or not f.is_inside_tree() or f.is_defeated():
			continue
		var d := absf(f.global_position.x - me.global_position.x)
		if d < best_d:
			best_d = d
			best = f
	return best


func think(delta: float) -> void:
	for a in _hold_t.keys():
		_hold_t[a] = float(_hold_t[a]) - delta
		if float(_hold_t[a]) <= 0.0:
			_release(a)
	_press_t -= delta
	_plan_t -= delta
	move_axis = 0.0
	climb_axis = 0.0
	var t := target()
	if t == null:
		_release("climb_down")
		return
	var dx := t.global_position.x - me.global_position.x
	var dist := absf(dx)
	var dir := signf(dx) if dist > 1.0 else me.facing_dir
	var busy := me.current_state in [PlayerController.State.ATTACKING, PlayerController.State.HURT, PlayerController.State.DODGING]

	_watch_opponent(t, dist, delta)
	if _react_t >= 0.0:
		_react_t -= delta
		if _react_t < 0.0:
			_do_reaction(dir)
	if is_held("climb_down"):
		climb_axis = 1.0
		if not busy and me.facing_dir != dir:
			me._set_facing(dir)
		return
	if is_held("special_action") and me.current_state == PlayerController.State.CHARGING:
		return

	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = float(p["think"]) * _rng.randf_range(0.7, 1.3)
		_decide(t, dist)

	match _plan:
		"approach":
			move_axis = dir
			if t.global_position.y < me.global_position.y - 40.0 and me.is_on_floor() and _press_t <= 0.0:
				_tap("jump")
				_press_t = 0.5
		"retreat":
			move_axis = -dir
		"attack":
			if dist > MELEE_RANGE + 6.0:
				move_axis = dir
			elif not busy and me.facing_dir != dir:
				move_axis = dir * 0.06
			_run_combo(dist)
		"ranged":
			if me.facing_dir != dir:
				move_axis = dir * 0.06
			elif _press_t <= 0.0:
				_tap("web_action")
				stats["attacks"] += 1
				_press_t = 0.6
				_plan = "approach"
		"charge":
			if me.is_on_floor():
				_hold("special_action", 1.1)
				_tap("special_action")
			_plan = "idle"
		"idle":
			pass


func _decide(t: PlayerController, dist: float) -> void:
	var aggr: float = p["aggr"]
	var meter := me.power_meter
	# specials when in reach and the meter allows it
	if dist < 60.0 and meter >= 100.0 and _rng.randf() < float(p["special"]) * 0.45:
		_use_special(meter)
		return
	if me.sp_style == "blast" and meter >= 100.0 and dist > 90.0 and _rng.randf() < float(p["special"]) * 0.35:
		_face(t)
		_tap("special_action")
		stats["specials"] += 1
		return
	if dist <= MELEE_RANGE + 10.0:
		if _rng.randf() < aggr:
			_plan = "attack"
			_combo_left = _rng.randi_range(1, int(p["combo"]))
		elif _rng.randf() < float(p["guard"]) and t.current_state != PlayerController.State.CHARGING:
			_hold("climb_down", _rng.randf_range(0.3, 0.7))
			stats["blocks_started"] += 1
		else:
			_plan = "retreat" if _rng.randf() < 0.5 else "idle"
	elif dist < 200.0:
		if meter < 100.0 and dist > 130.0 and _rng.randf() < 0.25 * float(p["special"]) + 0.05:
			_plan = "charge"
		elif _rng.randf() < 0.18:
			_plan = "ranged"
		elif _rng.randf() < 0.12 + float(p["dodge"]) * 0.3 and dist > 60.0:
			# dash in: dodge toward the opponent then strike
			_face(t)
			_tap("dodge")
			_plan = "attack"
			_combo_left = 1
			_press_t = 0.12
			stats["dodges"] += 1
		else:
			_plan = "approach" if _rng.randf() < 0.4 + aggr * 0.6 else "idle"
	else:
		_plan = "approach"


func _face(t: PlayerController) -> void:
	var d := signf(t.global_position.x - me.global_position.x)
	if d != 0.0 and d != me.facing_dir:
		me._set_facing(d)


func _use_special(meter: float) -> void:
	stats["specials"] += 1
	if meter >= 300.0 and _rng.randf() < 0.75:
		_hold("climb_down", 0.15)
	elif meter >= 200.0 and _rng.randf() < 0.7:
		_hold("climb_up", 0.15)
	_tap("special_action")


func _run_combo(dist: float) -> void:
	if _combo_left <= 0 or _press_t > 0.0 or dist > MELEE_RANGE + 6.0:
		if _combo_left <= 0:
			_plan = "retreat" if _rng.randf() > float(p["aggr"]) else "idle"
			_plan_t = 0.25
			_think_t = maxf(_think_t, float(p["rest"]) * _rng.randf_range(0.7, 1.3))
		return
	stats["attacks"] += 1
	var roll := _rng.randf()
	if int(p["combo"]) >= 3 and roll < 0.18:
		_hold("attack_punch", 0.35)          # heavy: punch held through the jab
		_tap("attack_punch")
		_press_t = 0.6
	elif _combo_left == 1 and roll < 0.4:
		_tap("attack_kick")
		_press_t = 0.3
	else:
		_tap("attack_punch")
		_press_t = _rng.randf_range(0.12, 0.2)
	_combo_left -= 1


## Notices when the opponent starts a new attack or a projectile comes in and schedules a reaction.
func _watch_opponent(t: PlayerController, dist: float, _delta: float) -> void:
	var st := int(t.current_state)
	var attacking := st == PlayerController.State.ATTACKING
	var new_attack := attacking and (_last_target_state != st or t._attack_elapsed < _last_target_elapsed - 0.001)
	_last_target_state = st
	_last_target_elapsed = t._attack_elapsed
	if new_attack and dist < 90.0 and _react_t < 0.0:
		var roll := _rng.randf()
		var parry_p: float = p["parry"]
		var block_p: float = p["block"]
		if roll < parry_p:
			_react_kind = "parry"
			stats["parry_attempts"] += 1
			# start the guard ~0.1s before the strike lands so it counts as a parry
			_react_t = maxf(0.0, maxf(float(p["react"]) * 0.5, t._attack_hitbox_start - t._attack_elapsed - 0.1))
		elif roll < parry_p + block_p:
			_react_kind = "block"
			_react_t = float(p["react"])
		elif roll < parry_p + block_p + float(p["dodge"]):
			_react_kind = "dodge"
			_react_t = float(p["react"])
	# incoming web shots / blasts
	if _react_t < 0.0:
		for pr in me.get_tree().get_nodes_in_group("projectiles"):
			var w := pr as WebProjectile
			if w == null or w.shooter == me or not is_instance_valid(w):
				continue
			var d := (w.global_position - me.global_position)
			if absf(d.x) < 70.0 and absf(d.y) < 30.0 and _rng.randf() < float(p["block"]) * 0.2:
				_react_kind = "block" if _rng.randf() < 0.6 else "jump"
				_react_t = float(p["react"]) * 0.5
				break


func _do_reaction(dir: float) -> void:
	match _react_kind:
		"parry", "block":
			if me.is_on_floor() and me.current_state != PlayerController.State.ATTACKING:
				if me.facing_dir != dir:
					me._set_facing(dir)
				_hold("climb_down", 0.45 if _react_kind == "block" else 0.3)
				stats["blocks_started"] += 1
		"dodge":
			move_axis = -dir
			_tap("dodge")
			stats["dodges"] += 1
		"jump":
			_tap("jump")
	_react_kind = ""
