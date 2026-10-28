class_name VersusLevel
extends Node2D
## Versus match: 1 VS 1 or 3 VS 3 (elimination - knock out all three of the other team to win) between the
## player's Spider-Verse fighters and a bot team, or CPU vs CPU. Each bout has a 99s timer (on time-out the
## fighter with less health loses the bout). In 3v3 a fighter can TAG out (C / SUIT button) to a teammate,
## who dashes in; health and power are kept per fighter. Results pay tokens and feed versus records.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud_and_touch.tscn")
const FLOOR_Y: float = 300.0
const ARENA_W: float = 900.0
const BOUT_TIME: float = 99.0
const TAG_COOLDOWN: float = 10.0
## Versus pacing: more health and less damage than story mode so bouts last like a fighting game
const HP_SCALE: float = 1.6
const DMG_SCALE: float = 0.5
const STAGES: Array[String] = ["street_dusk", "rooftop_sunset", "night_industrial", "goblin_facility", "storm_finale"]
const STAGE_NAMES: Dictionary = {"street_dusk": "DUSK ROOFTOPS", "rooftop_sunset": "SUNSET SKYLINE",
	"night_industrial": "CHEMICAL YARD", "goblin_facility": "GOBLIN LAB", "storm_finale": "STORM TOWER"}
## token reward for a win per difficulty (x1.6 for 3v3)
const WIN_TOKENS: Dictionary = {"easy": 60, "moderate": 110, "difficult": 180, "more_difficult": 280}

## Match config (set before adding to the tree, or taken from GameState.versus_config)
var config: Dictionary = {}
var difficulty: String = "moderate"
var teams: Array = [[], [], []]        # index 1 / 2
var cpu_vs_cpu: bool = false

var world: Node2D
var cam: Camera2D
var hud: HudAndTouchUI
var vhud: VersusHUD
var post_fx: PostFX
var active: Array = [null, null, null]
var slots: Array = [[], [], []]         # per team: [{hp, meter, alive}]
var current: Array = [0, 0, 0]
var bout_time: float = BOUT_TIME
var bout: int = 0
var finished: bool = false
var winner: int = 0
var paused_flow: bool = true
var tag_cd: Array = [0.0, 0.0, 0.0]
var player_stats: Dictionary = {}
var last_result: Dictionary = {}
var _bot_tagged: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _match_time: float = 0.0


func _ready() -> void:
	if config.is_empty():
		config = GameState.versus_config
	difficulty = String(config.get("difficulty", "moderate"))
	teams[1] = config.get("team1", ["miles"])
	teams[2] = config.get("team2", ["noir"])
	cpu_vs_cpu = bool(config.get("cpu_vs_cpu", false))
	_rng.randomize()
	var stage := String(config.get("stage", "random"))
	if not stage in STAGES:
		stage = STAGES[_rng.randi_range(0, STAGES.size() - 1)]
	LevelBuilder.build_background(self, stage)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	var b := LevelBuilder.new(_stage_data(stage), world)
	b.build_all()
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(ARENA_W)
	cam.limit_top = -260
	cam.limit_bottom = int(FLOOR_Y) + 70
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.position = Vector2(ARENA_W * 0.5, FLOOR_Y - 80)
	world.add_child(cam)
	cam.make_current()
	post_fx = PostFX.new()
	add_child(post_fx)
	post_fx.apply_theme(stage)

	hud = HUD_SCENE.instantiate() as HudAndTouchUI
	hud.layer = 10
	add_child(hud)
	hud.enable_campaign_mode()
	hud.get_node("RootControl/TopLeftHUD").visible = false
	# TAG / PAUSE move to the bottom centre, between the two touch clusters
	var bar := hud.get_node("RootControl/TopRightBar") as Control
	var vs := get_viewport().get_visible_rect().size
	bar.position = Vector2(maxf(640.0, vs.x) * 0.5 - 60.0, maxf(360.0, vs.y) - 36.0)
	hud.btn_suit.text = "TAG" if teams[1].size() > 1 else "-"
	hud.btn_suit.disabled = teams[1].size() < 2
	hud.restart_requested.connect(rematch)
	hud.restart_level_requested.connect(rematch)
	hud.menu_requested.connect(func() -> void: GameState.goto_versus_setup())
	vhud = VersusHUD.new()
	hud.get_node("RootControl").add_child(vhud)
	hud.get_node("RootControl").move_child(vhud, 1)
	vhud.mode_label.text = "%s  |  %s" % ["%d VS %d" % [teams[1].size(), teams[2].size()], FighterAI.NAMES.get(difficulty, "")]
	if cpu_vs_cpu:
		hud.set_touch_visible(false)

	for t in [1, 2]:
		slots[t] = []
		for k in teams[t]:
			slots[t].append({"hp": -1, "meter": PlayerController.METER_START, "alive": true})
		vhud.set_team(t - 1, teams[t], _alive_list(t))
	player_stats = {"hits": 0, "max_combo": 0, "parries": 0, "blocks": 0, "damage_taken": 0, "damage_dealt": 0, "specials": 0}
	Audio.play_music("boss_theme")
	_start_bout(true)


func _stage_data(theme: String) -> Dictionary:
	var surf := {"street_dusk": "concrete", "rooftop_sunset": "rooftile", "night_industrial": "metal",
		"goblin_facility": "metal", "storm_finale": "brick_dark"}
	return {
		"number": 0, "theme": theme, "bounds": Rect2(0, -260, ARENA_W, 640), "spawn": Vector2(ARENA_W * 0.5, FLOOR_Y),
		"solids": [[-60, -400, 72, 820, "brick_dark"], [ARENA_W - 12, -400, 72, 820, "brick_dark"],
			[0, FLOOR_Y, ARENA_W, 140, surf.get(theme, "concrete")]],
		"one_way": [[170, 220, 120, "girder"], [ARENA_W - 290, 220, 120, "girder"]],
		"anchors": [[300, 110], [ARENA_W - 300, 110]],
		"props": [["water_tower", 90, FLOOR_Y, 1.0], ["antenna", ARENA_W - 110, FLOOR_Y, 1.0, true], ["ac_unit", ARENA_W * 0.5, FLOOR_Y, 0.9]],
	}


func _alive_list(t: int) -> Array:
	var out: Array = []
	for s in slots[t]:
		out.append(bool(s["alive"]))
	return out


# ------------------------------------------------------------------ fighters
func _spawn(t: int, slot: int, x: float) -> PlayerController:
	var key := String(teams[t][slot])
	var info := SpiderRoster.info(key)
	var f := PLAYER_SCENE.instantiate() as PlayerController
	var bot := t == 2 or cpu_vs_cpu
	if bot:
		f.is_bot = true
		f.controller = FighterAI.new(f, difficulty if t == 2 else "difficult", int(config.get("ai_seed", 0)) * t)
	f.position = Vector2(x, FLOOR_Y - 16.0)
	world.add_child(f)
	f.setup_fighter(key, info, t)
	f.damage_mult *= DMG_SCALE
	f.health_component.max_health = int(round(float(info["hp"]) * HP_SCALE))
	f.health_component.reset_health()
	f.health_component.invulnerability_duration = 0.35 if f.passive == "evasion" else 0.15
	if t == 2:
		f.damage_mult *= float(FighterAI.LEVELS[difficulty]["dmg"])
	var s: Dictionary = slots[t][slot]
	if int(s["hp"]) > 0:
		f.health_component.current_health = int(s["hp"])
		f.health_component.health_changed.emit(f.health_component.current_health, f.health_component.max_health)
	f.set_meter(float(s["meter"]))
	f._set_facing(1.0 if t == 1 else -1.0)
	f.player_died.connect(_on_ko.bind(t, f))
	active[t] = f
	current[t] = slot
	vhud.bind_fighter(t - 1, f)
	return f


func _save_slot(t: int) -> void:
	var f: PlayerController = active[t]
	if f == null or not is_instance_valid(f):
		return
	var s: Dictionary = slots[t][current[t]]
	s["hp"] = f.health_component.current_health
	s["meter"] = f.power_meter
	if t == 1:
		for k in f.stats:
			if k == "max_combo":
				player_stats[k] = maxi(int(player_stats[k]), int(f.stats[k]))
			else:
				player_stats[k] = int(player_stats.get(k, 0)) + int(f.stats[k])
		f.reset_stats()


func _next_alive(t: int, from: int) -> int:
	for i in range(1, slots[t].size() + 1):
		var j: int = (from + i) % slots[t].size()
		if bool(slots[t][j]["alive"]):
			return j
	return -1


func _start_bout(first: bool) -> void:
	bout += 1
	paused_flow = true
	bout_time = BOUT_TIME
	for t in [1, 2]:
		if active[t] == null or not is_instance_valid(active[t]) or (active[t] as PlayerController).is_defeated():
			var slot: int = current[t] if bool(slots[t][current[t]]["alive"]) else _next_alive(t, current[t])
			if active[t] != null and is_instance_valid(active[t]):
				(active[t] as Node).queue_free()
			var other: PlayerController = active[3 - t] if active[3 - t] != null and is_instance_valid(active[3 - t]) else null
			var x := ARENA_W * 0.5 + (-110.0 if t == 1 else 110.0)
			if other != null and not other.is_defeated():
				x = clampf(other.global_position.x + (-140.0 if t == 1 else 140.0), 60.0, ARENA_W - 60.0)
			_spawn(t, slot, x)
	for t in [1, 2]:
		(active[t] as PlayerController).input_locked = true
		(active[t] as PlayerController).health_component.grant_invulnerability(1.4)
	var n1 := String(SpiderRoster.info(String(teams[1][current[1]]))["name"])
	var n2 := String(SpiderRoster.info(String(teams[2][current[2]]))["name"])
	vhud.show_banner("ROUND %d" % bout, "%s  VS  %s" % [n1, n2], 0.9)
	Audio.play_sfx("boss_warn", 0.6)
	await get_tree().create_timer(1.3 if first else 1.0).timeout
	if finished or not is_inside_tree():
		return
	vhud.show_banner("FIGHT!", "", 0.5)
	for t in [1, 2]:
		if is_instance_valid(active[t]):
			(active[t] as PlayerController).input_locked = false
	paused_flow = false


func _on_ko(t: int, f: PlayerController) -> void:
	if finished or f != active[t]:
		return
	paused_flow = true
	_save_slot(t)
	_save_slot(3 - t)
	slots[t][current[t]]["alive"] = false
	slots[t][current[t]]["hp"] = 0
	vhud.set_team(t - 1, teams[t], _alive_list(t))
	var winner_f: PlayerController = active[3 - t]
	if is_instance_valid(winner_f):
		winner_f.input_locked = true
		winner_f.health_component.grant_invulnerability(3.0)
	Fx.hitstop(0.45, 0.25)
	Fx.flash(Color(1, 1, 1, 0.5), 0.3)
	vhud.show_banner("K.O.!", String(SpiderRoster.info(f.character_key)["name"]) + " is down", 1.0)
	Audio.play_sfx("explosion", 0.8)
	await get_tree().create_timer(1.8).timeout
	if not is_inside_tree():
		return
	if _next_alive(t, current[t]) < 0:
		_finish(3 - t)
		return
	if is_instance_valid(winner_f):
		winner_f.health_component.current_health = mini(winner_f.health_component.max_health,
			winner_f.health_component.current_health + int(winner_f.health_component.max_health * 0.1))
		winner_f.health_component.health_changed.emit(winner_f.health_component.current_health, winner_f.health_component.max_health)
		winner_f.input_locked = false
	_start_bout(false)


## In 3v3, swap the active fighter for the next healthy teammate, who enters with a dash strike.
func tag(t: int) -> bool:
	if paused_flow or finished or tag_cd[t] > 0.0 or slots[t].size() < 2:
		return false
	var f: PlayerController = active[t]
	if f == null or not is_instance_valid(f) or f.is_defeated() or f.current_state == PlayerController.State.HURT:
		return false
	var nxt := _next_alive(t, current[t])
	if nxt < 0 or nxt == current[t]:
		return false
	_save_slot(t)
	var pos := f.global_position
	var facing := f.facing_dir
	f.remove_from_group("team%d" % t)
	f.remove_from_group("player")
	f.queue_free()
	var nf := _spawn(t, nxt, pos.x)
	nf.global_position = pos
	nf._set_facing(facing)
	nf.health_component.grant_invulnerability(0.6)
	nf._start_melee_attack(4)
	tag_cd[t] = TAG_COOLDOWN
	Fx.burst(world, pos, nf.fx_color, 20, 160.0, 0.0, 0.4)
	Audio.play_sfx("whoosh", 0.9)
	vhud.show_banner("TAG IN!", String(SpiderRoster.info(nf.character_key)["name"]), 0.5)
	return true


func _physics_process(delta: float) -> void:
	_update_camera(delta)
	if finished:
		return
	for t in [1, 2]:
		tag_cd[t] = maxf(0.0, tag_cd[t] - delta)
	if paused_flow:
		return
	_match_time += delta
	bout_time -= delta
	vhud.set_time(bout_time)
	_separate_fighters()
	# human tag input (C / TAG button)
	if not cpu_vs_cpu and Input.is_action_just_pressed("suit_toggle"):
		tag(1)
	# bot tags out when hurt on harder levels
	var bf: PlayerController = active[2]
	if is_instance_valid(bf) and difficulty in ["difficult", "more_difficult"] and not _bot_tagged.has(current[2]):
		var r := float(bf.health_component.current_health) / float(bf.health_component.max_health)
		if r < 0.3 and bf.current_state in [PlayerController.State.IDLE, PlayerController.State.RUNNING]:
			_bot_tagged[current[2]] = true
			tag(2)
	if bout_time <= 0.0:
		_time_over()


func _time_over() -> void:
	paused_flow = true
	var a: PlayerController = active[1]
	var b: PlayerController = active[2]
	var ra := float(a.health_component.current_health) / a.health_component.max_health
	var rb := float(b.health_component.current_health) / b.health_component.max_health
	vhud.show_banner("TIME!", "", 0.6)
	var loser := b if ra >= rb else a
	loser.health_component.is_invulnerable = false
	loser.health_component.take_damage(99999, Vector2.ZERO, "time_over")


func _separate_fighters() -> void:
	var a: PlayerController = active[1]
	var b: PlayerController = active[2]
	if not is_instance_valid(a) or not is_instance_valid(b) or a.is_defeated() or b.is_defeated():
		return
	var dx := b.global_position.x - a.global_position.x
	if absf(dx) < 16.0 and absf(b.global_position.y - a.global_position.y) < 26.0:
		var push := (16.0 - absf(dx)) * 0.5 * (1.0 if dx >= 0.0 else -1.0)
		a.global_position.x = clampf(a.global_position.x - push, 20.0, ARENA_W - 20.0)
		b.global_position.x = clampf(b.global_position.x + push, 20.0, ARENA_W - 20.0)


func _update_camera(_delta: float) -> void:
	var pts: Array[Vector2] = []
	for t in [1, 2]:
		if is_instance_valid(active[t]):
			pts.append((active[t] as Node2D).global_position)
	if pts.is_empty():
		return
	var mid := Vector2.ZERO
	var min_y := INF
	for v in pts:
		mid += v
		min_y = minf(min_y, v.y)
	mid /= pts.size()
	var dist := absf(pts[0].x - pts[-1].x) if pts.size() > 1 else 0.0
	var z := clampf(640.0 * 0.62 / (dist + 70.0), 1.3, 2.3)
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 0.08)
	var view_h := 360.0 / cam.zoom.y
	var y := minf(FLOOR_Y - view_h * 0.32, min_y - 10.0)
	cam.position = Vector2(mid.x, y)


# ------------------------------------------------------------------ results
func _finish(winning_team: int) -> void:
	finished = true
	winner = winning_team
	paused_flow = true
	_save_slot(1)
	var won := winning_team == 1
	var w: PlayerController = active[winning_team]
	if is_instance_valid(w):
		w.input_locked = true
		w.sprite.play("victory", true)
	var r := Scoring.evaluate(player_stats, _match_time, 60.0 * teams[1].size(), 800 * teams[1].size())
	var mult := 1.6 if teams[1].size() > 1 else 1.0
	if cpu_vs_cpu:
		r["tokens"] = 0
	elif won:
		r["tokens"] = int(int(WIN_TOKENS.get(difficulty, 100)) * mult) + int(r["tokens"]) / 4
	else:
		r["tokens"] = 25
	last_result = r
	if not cpu_vs_cpu:
		GameState.record_versus(won, difficulty, teams[1], teams[1].size() > 1)
		GameState.add_tokens(int(r["tokens"]))
	Audio.play_music("victory_jingle" if won or cpu_vs_cpu else "defeat_jingle", 0.2, false)
	var team_name := "PLAYER" if not cpu_vs_cpu else "BLUE TEAM"
	vhud.show_banner(("%s WINS!" % team_name) if won else ("BOT WINS!" if not cpu_vs_cpu else "RED TEAM WINS!"),
		"Flawless!" if won and _alive_count(1) == teams[1].size() and int(player_stats["damage_taken"]) == 0 else "", 2.0)
	await get_tree().create_timer(2.2).timeout
	if not is_inside_tree():
		return
	var panel := ResultsPanel.new()
	hud.get_node("RootControl").add_child(panel)
	panel.show_result("VICTORY" if won else "DEFEAT", r, false)
	var row := HBoxContainer.new()
	row.position = Vector2(170, 286)
	row.add_theme_constant_override("separation", 8)
	hud.get_node("RootControl").add_child(row)
	var again := UIKit.button("REMATCH", 11, Vector2(96, 26))
	again.name = "Rematch"
	again.pressed.connect(rematch)
	row.add_child(again)
	var change := UIKit.button("NEW FIGHTERS", 11, Vector2(110, 26))
	change.pressed.connect(func() -> void: GameState.goto_versus_setup())
	row.add_child(change)
	var menu := UIKit.button("MENU", 11, Vector2(80, 26))
	menu.pressed.connect(GameState.goto_title)
	row.add_child(menu)
	again.grab_focus()


func _alive_count(t: int) -> int:
	var n := 0
	for s in slots[t]:
		if bool(s["alive"]):
			n += 1
	return n


func rematch() -> void:
	GameState.start_versus(config)
