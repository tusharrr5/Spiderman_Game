class_name CampaignLevel
extends Node2D
## Generic chapter controller. Builds the chapter from LevelRegistry data and runs the shared systems:
## objectives, checkpoints/respawn, dialogue triggers, boss wiring, scripted story events, escape timers,
## weather, pitfalls, death/retry (always the CURRENT chapter) and chapter completion.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud_and_touch.tscn")

## Tests may set this before adding the node to load a specific chapter without GameState routing.
var level_number: int = 0

var data: Dictionary = {}
var builder: LevelBuilder
var world: Node2D
var player: PlayerController
var hud: HudAndTouchUI
var dialogue: DialogueBox
var diagnostics_overlay: InputDiagnosticsOverlay
var follower: FollowerNPC
var last_result: Dictionary = {}
var post_fx: PostFX
var camera_director: CombatCamera

var objectives: Array = []
var obj_index: int = 0
var level_time: float = 0.0
var completed: bool = false
var failed: bool = false
var _flags: Dictionary = {}
var _escape_time: float = -1.0
var _boss_defeated: bool = false
var _tag_totals: Dictionary = {}
var _crate_timer: float = 0.0
var _lightning_timer: float = 3.0
var _rain: CPUParticles2D


func _ready() -> void:
	if level_number <= 0:
		level_number = GameState.current_level
	data = LevelRegistry.get_level(level_number)
	if data.is_empty():
		push_error("Unknown level %d" % level_number)
		return
	LevelBuilder.build_background(self, String(data["theme"]))
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	builder = LevelBuilder.new(data, world)
	builder.build_all()

	player = PLAYER_SCENE.instantiate() as PlayerController
	player.position = _spawn_position()
	world.add_child(player)
	_configure_camera()
	var suit := GameState.suit_equipped
	if suit == "classic" and GameState.dark_suit_unlocked and level_number >= 4:
		suit = "dark"
	if suit != "classic":
		player.apply_suit(suit)

	post_fx = PostFX.new()
	add_child(post_fx)
	post_fx.apply_theme(String(data["theme"]))
	camera_director = CombatCamera.new()
	add_child(camera_director)
	camera_director.setup(player)

	hud = HUD_SCENE.instantiate() as HudAndTouchUI
	hud.layer = 10
	add_child(hud)
	hud.enable_campaign_mode()
	hud.attach_fight_hud(player)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	diagnostics_overlay = InputDiagnosticsOverlay.new()
	diagnostics_overlay.show_diagnostics = false
	add_child(diagnostics_overlay)
	hud.touch_button_event.connect(diagnostics_overlay.record_onscreen_button)

	_wire_signals()
	objectives = data.get("objectives", [])
	_apply_checkpoint_progress()
	_start_objective(obj_index, true)
	_setup_weather()

	Audio.play_music(String(data.get("music", "ch1_streets")))
	hud.show_banner(String(data["chapter"]), String(data["title"]), 2.4)
	player.health_component.grant_invulnerability(1.0)
	if not GameState.seen_controls_guide and not DisplayServer.get_name().contains("headless"):
		hud.show_controls_guide(true)


func _spawn_position() -> Vector2:
	var cps: Array = data.get("checkpoints", [])
	if GameState.current_level == level_number and GameState.checkpoint_index >= 0 and GameState.checkpoint_index < cps.size():
		var c: Array = cps[GameState.checkpoint_index]
		return Vector2(c[0], float(c[1]) - 16.0)
	var s: Vector2 = data["spawn"]
	return Vector2(s.x, s.y - 16.0)


func _configure_camera() -> void:
	var cam := player.get_node("Camera2D") as Camera2D
	var b: Rect2 = data["bounds"]
	cam.limit_left = int(b.position.x)
	cam.limit_right = int(b.end.x)
	cam.limit_top = int(b.position.y)
	cam.limit_bottom = int(b.end.y) - 120
	cam.position_smoothing_speed = 7.0
	# closer framing so characters read clearly on phones; levels are built for this 512x288 view
	cam.zoom = Vector2(1.25, 1.25)
	cam.drag_horizontal_enabled = true
	cam.drag_left_margin = 0.1
	cam.drag_right_margin = 0.1
	cam.reset_smoothing()


func _wire_signals() -> void:
	player.health_component.health_changed.connect(hud.update_player_health)
	player.state_changed.connect(hud.update_player_state)
	player.combo_updated.connect(hud.update_combo_banner)
	player.ability_cooldown_updated.connect(hud.update_ability_cooldowns)
	player.player_died.connect(_on_player_died)
	hud.update_player_health(player.health_component.current_health, player.health_component.max_health)
	hud.update_ability_cooldowns(true, true, player.is_dark_suit)
	hud.restart_requested.connect(func() -> void: GameState.retry_level(true))
	hud.restart_level_requested.connect(func() -> void: GameState.retry_level(false))
	hud.menu_requested.connect(func() -> void: GameState.goto_level_select())

	for cp in builder.checkpoints:
		cp.activated.connect(_on_checkpoint)
	for t in builder.triggers:
		t.activated.connect(_on_trigger)
	if builder.cage != null:
		builder.cage.broken.connect(_on_cage_broken)
	if builder.exit_zone != null:
		builder.exit_zone.activated.connect(func(_z: InteractiveZone) -> void: _flags["exit"] = true)

	var b := builder.boss
	if b != null:
		b.boss_engaged.connect(hud.show_boss_hud)
		b.boss_health_updated.connect(hud.update_boss_health)
		b.boss_status_changed.connect(hud.update_boss_status)
		b.boss_defeated.connect(_on_boss_defeated)
		if b is ThiefBoss:
			(b as ThiefBoss).cornered.connect(func() -> void: _flags["thief_cornered"] = true)
		if b is GoblinBoss:
			(b as GoblinBoss).scripted_finale.connect(_on_goblin_scripted_finale)


func _apply_checkpoint_progress() -> void:
	if GameState.current_level != level_number or GameState.checkpoint_index < 0:
		return
	obj_index = clampi(GameState.checkpoint_objective, 0, maxi(0, objectives.size() - 1))
	for i in range(mini(GameState.checkpoint_index + 1, builder.checkpoints.size())):
		builder.checkpoints[i].set_reached()
	# skip story triggers behind the respawn point
	for t in builder.triggers:
		if t.global_position.x < player.global_position.x - 8.0:
			t.active = false
	# a fleeing thief is moved ahead of the respawn point so the chase resumes naturally
	if builder.boss is ThiefBoss and not _flags.has("thief_cornered"):
		var th := builder.boss as ThiefBoss
		var ahead := float(data["boss"].get("respawn_ahead", 240.0))
		var nx := player.global_position.x + ahead
		if nx < th.arena_left_x:
			th.global_position = Vector2(nx, player.global_position.y - 20.0)
			var r: Array = th.route
			while th._route_i < r.size() and float(r[th._route_i]["x"]) < nx:
				th._route_i += 1


# ------------------------------------------------------------------ objectives
func _start_objective(i: int, silent: bool = false) -> void:
	obj_index = i
	if i >= objectives.size():
		_complete_level()
		return
	var o: Dictionary = objectives[i]
	hud.set_objective(String(o.get("text", "")))
	if not silent:
		hud.show_banner("NEW OBJECTIVE", String(o.get("text", "")), 1.6)
	if o.has("music"):
		Audio.play_music(String(o["music"]))
	match String(o["type"]):
		"defeat_tag":
			_tag_totals[o["tag"]] = get_tree().get_nodes_in_group(String(o["tag"])).size()
		"escape":
			_escape_time = float(o.get("time", 60.0))
			if builder.exit_zone != null:
				builder.exit_zone.active = true
		"collect":
			_spawn_collectible(String(o["id"]))


func _objective_done() -> bool:
	if obj_index >= objectives.size():
		return false
	var o: Dictionary = objectives[obj_index]
	match String(o["type"]):
		"reach":
			return player.global_position.x >= float(o["x"])
		"defeat_tag":
			var alive := 0
			var total := 0
			for e in get_tree().get_nodes_in_group(String(o["tag"])):
				total += 1
				if e is EnemyBase and not (e as EnemyBase).is_defeated():
					alive += 1
			hud.set_objective("%s (%d/%d)" % [o["text"], total - alive, total])
			return alive == 0
		"defeat_boss":
			return _boss_defeated
		"thief_cornered":
			return _flags.has("thief_cornered")
		"collect":
			return _flags.has("collected_" + String(o["id"]))
		"break_tag":
			var left := 0
			var total2 := 0
			for t in get_tree().get_nodes_in_group(String(o["tag"])):
				total2 += 1
				if t is BreakableTarget and not (t as BreakableTarget).is_broken:
					left += 1
			hud.set_objective("%s (%d/%d)" % [o["text"], total2 - left, total2])
			return left == 0
		"rescue":
			return _flags.has("rescued")
		"escape":
			return _flags.has("exit")
		"scripted":
			return _flags.has("scripted_done")
	return false


func _process(delta: float) -> void:
	if data.is_empty() or completed:
		return
	if not get_tree().paused and not failed:
		level_time += delta
	if failed:
		return
	if _objective_done():
		Audio.play_sfx("checkpoint", 0.7)
		_start_objective(obj_index + 1)
	if _escape_time >= 0.0 and not completed:
		_escape_time -= delta
		hud.set_timer(maxf(0.0, _escape_time))
		if _escape_time <= 0.0:
			_escape_time = -1.0
			hud.set_timer(-1.0)
			Fx.flash(Color(1, 0.5, 0.2, 0.6), 0.5)
			player.health_component.take_damage(999, Vector2.ZERO, "lockdown")
	_update_crates(delta)
	_update_weather(delta)


func _physics_process(_delta: float) -> void:
	if player == null or failed or completed:
		return
	var b: Rect2 = data["bounds"]
	if player.current_state != PlayerController.State.DEFEATED and player.global_position.y > b.end.y:
		player.health_component.take_damage(999, Vector2.ZERO, "pitfall")


# ------------------------------------------------------------------ events
func _on_checkpoint(z: InteractiveZone) -> void:
	GameState.reach_checkpoint(z.index)
	GameState.checkpoint_objective = obj_index
	hud.show_banner("CHECKPOINT", "", 1.0)


func _on_trigger(z: InteractiveZone) -> void:
	var t: Dictionary = z.payload
	if t.has("dialogue"):
		dialogue.queue_lines(t["dialogue"])


func _on_boss_defeated() -> void:
	_boss_defeated = true
	Fx.hitstop(0.25, 0.1)
	Fx.flash(Color(1, 1, 1, 0.5), 0.3)
	Audio.play_music(String(data.get("music", "ch1_streets")))


func _spawn_collectible(id: String) -> void:
	var pos := player.global_position + Vector2(40, 0)
	if builder.boss != null and is_instance_valid(builder.boss):
		pos = (builder.boss as Node2D).global_position
	var z := InteractiveZone.new()
	z.kind = "exit"
	z.zone_id = id
	z.size = Vector2(28, 28)
	z.payload = {"sprite": "tech_case"}
	z.position = pos + Vector2(0, -4)
	world.add_child(z)
	z.activated.connect(func(_zz: InteractiveZone) -> void:
		_flags["collected_" + id] = true
		Audio.play_sfx("pickup", 1.0)
		z.queue_free())


func _on_cage_broken(_t: BreakableTarget) -> void:
	_flags["rescued"] = true
	Audio.play_sfx("cage_break", 1.0)
	Fx.shake(4.0, 0.3)
	follower = FollowerNPC.new()
	follower.target = player
	follower.global_position = builder.cage.global_position + Vector2(0, 14)
	world.add_child(follower)
	dialogue.queue_lines([["mj", "You came for me!"], ["hero", "Hold on tight - this place is going into lockdown!"]])
	for e in data.get("rescue_wave", []):
		builder.spawn_enemy(e)
	builder.spawn_hazards(data.get("rescue_hazards", []))


func _on_goblin_scripted_finale() -> void:
	# Chapter 3's deliberate story defeat: a bomb barrage overwhelms the hero after a fair fight.
	player.input_locked = true
	player.health_component.grant_invulnerability(99.0)
	dialogue.clear()
	dialogue.queue_lines([["goblin", "Enough playtime! Let's see you dodge THIS!"]])
	var g := builder.boss as GoblinBoss
	for i in range(7):
		await get_tree().create_timer(0.28).timeout
		var p := player.global_position + Vector2(randf_range(-70, 70), randf_range(-30, 10))
		Fx.burst(world, p, Color(1.0, 0.5, 0.15), 24, 170.0, 100.0, 0.5)
		Audio.play_sfx("explosion", 0.9)
		Fx.shake(6.0, 0.3)
		if g != null:
			EnemyProjectile.spawn(world, "bomb", g.global_position, (p - g.global_position).normalized() * 220.0, 0, g)
	Fx.flash(Color(1, 0.8, 0.5, 0.9), 1.2)
	player.velocity = Vector2(-160, -180)
	player.sprite.play("defeated", true)
	player.current_state = PlayerController.State.DEFEATED
	await get_tree().create_timer(2.2).timeout
	_flags["scripted_done"] = true


func _on_player_died() -> void:
	if completed or failed:
		return
	failed = true
	_escape_time = -1.0
	hud.set_timer(-1.0)
	Audio.play_music("defeat_jingle", 0.3, false)
	await get_tree().create_timer(1.1).timeout
	hud.show_defeat_screen()


func _complete_level() -> void:
	if completed:
		return
	completed = true
	_escape_time = -1.0
	hud.set_timer(-1.0)
	hud.set_objective("")
	player.input_locked = true
	player.health_component.grant_invulnerability(99.0)
	Audio.play_music("victory_jingle", 0.2, false)
	var story_defeat := level_number == 3
	if not story_defeat and player.current_state != PlayerController.State.DEFEATED:
		player.sprite.play("victory", true)
	hud.show_banner("CHAPTER COMPLETE" if not story_defeat else "OVERWHELMED...", String(data["title"]), 2.2)
	var result := Scoring.evaluate(player.stats, level_time, float(data.get("par_time", 240.0)), 1000 * level_number)
	var new_best := GameState.record_chapter_result(level_number, int(result["score"]), String(result["rank"]), int(result["stars"]))
	GameState.add_tokens(int(result["tokens"]))
	last_result = result
	await get_tree().create_timer(1.4).timeout
	var panel := ResultsPanel.new()
	hud.get_node("RootControl").add_child(panel)
	panel.show_result(String(data["chapter"]) + "  RESULTS", result, new_best)
	await get_tree().create_timer(3.4).timeout
	GameState.finish_level(level_number, level_time)


# ------------------------------------------------------------------ crates & weather
func _update_crates(delta: float) -> void:
	if not data.has("respawn_crates_after_x"):
		return
	_crate_timer += delta
	if _crate_timer < 7.0:
		return
	_crate_timer = 0.0
	for c in get_tree().get_nodes_in_group("throwables"):
		var t := c as ThrowableObject
		if t != null and t.is_consumed and t.initial_spawn_position.x >= float(data["respawn_crates_after_x"]):
			t.reset_object()
			Fx.burst(world, t.global_position, Color(0.9, 0.95, 1.0), 8, 50.0, 0.0, 0.4)


func _setup_weather() -> void:
	if not data.get("rain", false):
		return
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_rain = CPUParticles2D.new()
	_rain.amount = 260
	_rain.lifetime = 0.7
	_rain.preprocess = 1.0
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(380, 4)
	_rain.position = Vector2(340, -10)
	_rain.direction = Vector2(-0.25, 1)
	_rain.spread = 3.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 520.0
	_rain.initial_velocity_max = 640.0
	_rain.scale_amount_min = 1.0
	_rain.scale_amount_max = 1.5
	_rain.color = Color(0.7, 0.78, 1.0, 0.45)
	layer.add_child(_rain)
	_rain.emitting = true


func _update_weather(delta: float) -> void:
	if not data.get("lightning", false):
		return
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(4.0, 9.0)
		Fx.flash(Color(0.85, 0.9, 1.0, 0.45), 0.25)
		Audio.play_sfx("explosion", 0.25)
