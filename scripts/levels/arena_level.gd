class_name ArenaLevel
extends Node2D
## Replayable fight modes on a walled rooftop arena, built from the same LevelBuilder / HUD / combat systems:
##   gauntlet - 4 escalating rounds (gang squad, the Thief, Brick, the Goblin) per tier; health carries over
##   survival - endless waves with a boss every 5th wave; the run ends on defeat and records best wave / score
##   daily    - a date-seeded lineup with one rule modifier; first clear each day pays a streak bonus
## Every run is scored with Scoring.evaluate and pays tokens for the upgrade / suit shop.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud_and_touch.tscn")
const FLOOR_Y: float = 300.0
const ARENA_W: float = 960.0
const THEMES: Array[String] = ["street_dusk", "rooftop_sunset", "night_industrial", "storm_finale"]

const GAUNTLET_ROUNDS: Array = [
	{"name": "THE RIVETS GANG", "enemies": ["thug", "thug", "gunner", "thug"]},
	{"name": "THE THIEF", "boss": "thief"},
	{"name": "BRICK", "boss": "brick"},
	{"name": "THE GOBLIN", "boss": "goblin"},
]
## modifier key -> [title, description]
const MODIFIERS: Dictionary = {
	"glass_cannon": ["GLASS CANNON", "You deal +50% damage but take +50% damage"],
	"power_surge": ["POWER SURGE", "Start with a full power meter; meter gain doubled"],
	"iron_guard": ["IRON GUARD", "Every foe blocks often - use heavies and specials"],
	"swarm": ["SWARM", "Extra enemies with less health"],
}

## Set before adding to the tree (tests) or taken from GameState.
var mode: String = ""
var tier: int = 1

var world: Node2D
var builder: LevelBuilder
var player: PlayerController
var hud: HudAndTouchUI
var post_fx: PostFX
var camera_director: CombatCamera
var round_index: int = 0
var wave: int = 0
var run_time: float = 0.0
var finished: bool = false
var failed: bool = false
var modifier: String = ""
var last_result: Dictionary = {}
var _alive: Array = []
var _lineup: Array = []
var _between: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if mode == "":
		mode = GameState.arena_mode
		tier = GameState.arena_tier
	if mode == "daily":
		_rng.seed = hash(GameState.today_key())
		modifier = MODIFIERS.keys()[_rng.randi_range(0, MODIFIERS.size() - 1)]
		_lineup = _daily_lineup()
	else:
		_rng.randomize()
		_lineup = GAUNTLET_ROUNDS
	var theme: String = THEMES[(tier - 1 + (2 if mode == "survival" else 0)) % THEMES.size()]
	LevelBuilder.build_background(self, theme)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	builder = LevelBuilder.new(_arena_data(theme), world)
	builder.build_all()

	player = PLAYER_SCENE.instantiate() as PlayerController
	player.position = Vector2(220, FLOOR_Y - 16.0)
	world.add_child(player)
	if GameState.suit_equipped != "classic":
		player.apply_suit(GameState.suit_equipped)
	var cam := player.get_node("Camera2D") as Camera2D
	cam.limit_left = 0
	cam.limit_right = int(ARENA_W)
	cam.limit_top = -200
	cam.limit_bottom = int(FLOOR_Y) + 60
	cam.reset_smoothing()

	post_fx = PostFX.new()
	add_child(post_fx)
	post_fx.apply_theme(theme)
	camera_director = CombatCamera.new()
	add_child(camera_director)
	camera_director.setup(player)

	hud = HUD_SCENE.instantiate() as HudAndTouchUI
	hud.layer = 10
	add_child(hud)
	hud.enable_campaign_mode()
	hud.attach_fight_hud(player)
	player.health_component.health_changed.connect(hud.update_player_health)
	player.combo_updated.connect(hud.update_combo_banner)
	player.player_died.connect(_on_player_died)
	hud.update_player_health(player.health_component.current_health, player.health_component.max_health)
	hud.restart_requested.connect(_restart)
	hud.restart_level_requested.connect(_restart)
	hud.menu_requested.connect(func() -> void: GameState.goto_arena_hub())

	_apply_modifier_to_player()
	Audio.play_music("boss_theme")
	var title: String = {"gauntlet": "GAUNTLET  -  TIER %d" % tier, "survival": "SURVIVAL", "daily": "DAILY CHALLENGE"}[mode]
	var sub: String = MODIFIERS[modifier][0] + ": " + MODIFIERS[modifier][1] if modifier != "" else "Fight!"
	hud.show_banner(title, sub, 2.4)
	_next_round(1.6)


func _arena_data(theme: String) -> Dictionary:
	var surf := {"street_dusk": "concrete", "rooftop_sunset": "rooftile", "night_industrial": "metal", "storm_finale": "brick_dark"}
	return {
		"number": 0, "chapter": "ARENA", "title": "ARENA", "theme": theme, "difficulty": difficulty(),
		"bounds": Rect2(0, -200, ARENA_W, 600), "spawn": Vector2(220, FLOOR_Y),
		"solids": [[-60, -400, 72, 820, "brick_dark"], [ARENA_W - 12, -400, 72, 820, "brick_dark"],
			[0, FLOOR_Y, ARENA_W, 140, surf.get(theme, "concrete")]],
		"one_way": [[150, 225, 110, "girder"], [ARENA_W - 260, 225, 110, "girder"]],
		"anchors": [[300, 120], [ARENA_W - 300, 120], [ARENA_W * 0.5, 100]],
		"crates": [[90, FLOOR_Y], [ARENA_W - 90, FLOOR_Y]],
		"props": [["water_tower", 120, FLOOR_Y, 1.0], ["ac_unit", ARENA_W * 0.5 - 140, FLOOR_Y, 1.0], ["antenna", ARENA_W - 160, FLOOR_Y, 1.0, true]],
	}


func difficulty() -> float:
	if mode == "survival":
		return 0.85 + 0.07 * wave
	return 0.85 + 0.25 * (tier - 1)


# ------------------------------------------------------------------ rounds
func _next_round(delay: float) -> void:
	_between = true
	await get_tree().create_timer(delay).timeout
	if finished or failed or not is_inside_tree():
		return
	_between = false
	builder.difficulty = difficulty()
	if mode == "survival":
		wave += 1
		_spawn_wave()
		hud.set_objective("WAVE %d  -  survive!" % wave)
		hud.show_banner("WAVE %d" % wave, "Boss wave!" if wave % 5 == 0 else "", 1.2)
	else:
		var r: Dictionary = _lineup[round_index]
		hud.set_objective("ROUND %d / %d  -  %s" % [round_index + 1, _lineup.size(), r["name"]])
		hud.show_banner("ROUND %d" % (round_index + 1), String(r["name"]), 1.4)
		if r.has("boss"):
			_spawn_boss(String(r["boss"]))
		for t in r.get("enemies", []):
			_spawn_enemy(String(t))
		if modifier == "swarm" and not r.has("boss"):
			_spawn_enemy("thug")
			_spawn_enemy("drone")
	Audio.play_sfx("boss_warn", 0.7)


func _spawn_wave() -> void:
	if wave % 5 == 0:
		_spawn_boss(["brick", "thief", "goblin"][(wave / 5 - 1) % 3])
		return
	var n := mini(2 + wave / 2, 6)
	for i in range(n):
		var roll := _rng.randf()
		var t := "thug"
		if wave >= 2 and roll < 0.3:
			t = "gunner"
		elif wave >= 3 and roll > 0.82:
			t = "drone"
		_spawn_enemy(t)


func _spawn_enemy(t: String) -> void:
	var side := 1.0 if _rng.randf() < 0.6 else -1.0
	var x := clampf(player.global_position.x + side * _rng.randf_range(170.0, 300.0), 60.0, ARENA_W - 60.0)
	var e := {"type": t, "x": x, "y": 140.0 if t == "drone" else FLOOR_Y}
	var node := builder.spawn_enemy(e) as EnemyBase
	node.detection_range = 900.0
	node.patrol_distance = 200.0
	node.guard_chance = 0.5 if modifier == "iron_guard" else clampf(0.08 * (tier - 1) + 0.02 * wave, 0.0, 0.35)
	if modifier == "swarm":
		node.health_component.max_health = int(node.health_component.max_health * 0.6)
		node.health_component.reset_health()
	_track(node)


func _spawn_boss(kind: String) -> void:
	var x := ARENA_W - 220.0 if player.global_position.x < ARENA_W * 0.5 else 220.0
	var b := {"type": kind, "x": x, "y": FLOOR_Y, "trigger_x": -1000.0, "left": 40.0, "right": ARENA_W - 40.0,
		"route": [], "mode": "final", "hp": int(300 + 60 * tier), "hover_y": 150.0, "floor_y": FLOOR_Y}
	b["name"] = {"brick": "BRICK", "thief": "THE THIEF", "goblin": "THE GOBLIN"}[kind]
	builder.boss = null
	builder.data["boss"] = b
	builder._build_boss()
	var boss := builder.boss
	if boss == null:
		return
	if boss is EnemyBase:
		(boss as EnemyBase).kill_y = FLOOR_Y + 200.0
		if modifier == "iron_guard":
			(boss as EnemyBase).guard_chance = 0.25
	if boss.has_signal("boss_engaged"):
		boss.boss_engaged.connect(hud.show_boss_hud)
		boss.boss_health_updated.connect(hud.update_boss_health)
		boss.boss_status_changed.connect(hud.update_boss_status)
	if boss.has_method("engage"):
		boss.call_deferred("engage")
	_track(boss)


func _track(n: Node) -> void:
	_alive.append(n)


func _physics_process(delta: float) -> void:
	if finished or failed:
		return
	run_time += delta
	if _between:
		return
	var any := false
	for n in _alive:
		if is_instance_valid(n) and not _is_down(n):
			any = true
			break
	if not any and not _alive.is_empty():
		_alive.clear()
		_round_cleared()


func _is_down(n: Node) -> bool:
	if n is PrototypeBoss:
		return (n as PrototypeBoss).state == PrototypeBoss.BossState.DEFEATED
	if n.has_method("is_defeated"):
		return bool(n.call("is_defeated"))
	return false


func _round_cleared() -> void:
	hud.hide_boss_hud()
	var heal := int(player.health_component.max_health * (0.15 if mode == "survival" else 0.25))
	player.health_component.current_health = mini(player.health_component.max_health, player.health_component.current_health + heal)
	player.health_component.health_changed.emit(player.health_component.current_health, player.health_component.max_health)
	if mode == "survival":
		Fx.popup_text(world, player.global_position + Vector2(0, -40), "+%d HP" % heal, Color(0.5, 1.0, 0.6), 10)
		_next_round(1.8)
		return
	round_index += 1
	if round_index >= _lineup.size():
		_finish(true)
		return
	Fx.popup_text(world, player.global_position + Vector2(0, -40), "ROUND CLEAR  +%d HP" % heal, Color(0.5, 1.0, 0.6), 10)
	_next_round(2.0)


# ------------------------------------------------------------------ results
func _on_player_died() -> void:
	if finished or failed:
		return
	failed = true
	if mode == "survival":
		await get_tree().create_timer(1.0).timeout
		_finish(false)
		return
	Audio.play_music("defeat_jingle", 0.3, false)
	await get_tree().create_timer(1.1).timeout
	hud.show_defeat_screen()


func _finish(victory: bool) -> void:
	finished = true
	player.input_locked = true
	player.health_component.grant_invulnerability(99.0)
	var base := 1500 * tier if mode == "gauntlet" else (600 * wave if mode == "survival" else 2500)
	var par := 150.0 + 30.0 * tier if mode != "survival" else 40.0 * maxf(1.0, wave)
	var r := Scoring.evaluate(player.stats, run_time, par, base)
	var title := ""
	match mode:
		"gauntlet":
			title = "TIER %d CLEARED" % tier
			r["tokens"] = int(r["tokens"]) + 120 * tier
			GameState.arena_best["gauntlet"] = maxi(int(GameState.arena_best.get("gauntlet", 0)), tier)
		"survival":
			title = "SURVIVED %d WAVES" % maxi(0, wave - 1)
			GameState.arena_best["survival"] = maxi(int(GameState.arena_best.get("survival", 0)), maxi(0, wave - 1))
		"daily":
			title = "DAILY CHALLENGE CLEARED"
			if GameState.daily_done != GameState.today_key():
				GameState.daily_streak = GameState.daily_streak + 1
				GameState.daily_done = GameState.today_key()
				r["tokens"] = int(r["tokens"]) + 250 + 50 * mini(GameState.daily_streak, 7)
	var key := mode + "_score"
	var new_best := int(r["score"]) > int(GameState.arena_best.get(key, 0))
	if new_best:
		GameState.arena_best[key] = int(r["score"])
	GameState.add_tokens(int(r["tokens"]))
	last_result = r
	if victory:
		Audio.play_music("victory_jingle", 0.2, false)
		player.sprite.play("victory", true)
	var panel := ResultsPanel.new()
	hud.get_node("RootControl").add_child(panel)
	panel.show_result(title, r, new_best)
	await get_tree().create_timer(4.5).timeout
	if is_inside_tree():
		GameState.goto_arena_hub()


func _restart() -> void:
	GameState.start_arena(mode, tier)


# ------------------------------------------------------------------ daily
func _daily_lineup() -> Array:
	var bosses := ["thief", "brick", "goblin"]
	var squad := []
	for i in range(3 + _rng.randi_range(0, 2)):
		squad.append(["thug", "gunner", "drone"][_rng.randi_range(0, 2)])
	var mid: String = bosses[_rng.randi_range(0, 1)]
	return [
		{"name": "STREET SQUAD", "enemies": squad},
		{"name": "BOSS: " + ("THE THIEF" if mid == "thief" else "BRICK"), "boss": mid},
		{"name": "FINAL: THE GOBLIN", "boss": "goblin"},
	]


func _apply_modifier_to_player() -> void:
	match modifier:
		"glass_cannon":
			player.damage_mult *= 1.5
			player.hurtbox.guard = func(dmg: int, kb: Vector2, t: String, a: Node) -> int:
				var d := player._guard_hit(dmg, kb, t, a)
				return d if d < 0 else int(round(d * 1.5))
		"power_surge":
			player.meter_gain_mult *= 2.0
			player.set_meter(PlayerController.METER_MAX)
