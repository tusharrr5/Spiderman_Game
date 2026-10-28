extends RefCounted
## Fighting-layer + replay regression suite: guard/chip, timed parry, hold-to-heavy, enemy guard and guard
## break, power meter specials (incl. the SP3 cinematic), scoring ranks, the token economy, and full
## Gauntlet / Survival arena runs. Real key events drive the player wherever input is under test.

var tree: SceneTree


func run(p_tree: SceneTree) -> bool:
	tree = p_tree
	Fx.hitstop_enabled = false
	GameState.save_path = "user://test_savegame.cfg"
	GameState.routing_enabled = false
	GameState.seen_controls_guide = true
	GameState.reset_progress()
	print("=== COMBAT & REPLAY SUITE ===")
	for t in [_test_block_and_parry, _test_heavy_and_guard_break, _test_specials, _test_scoring_and_economy,
			_test_gauntlet, _test_survival]:
		if not await t.call():
			return false
	GameState.reset_progress()
	GameState.routing_enabled = true
	GameState.save_path = "user://savegame.cfg"
	GameState.load_game()
	print("=== COMBAT & REPLAY SUITE PASSED ===")
	return true


# ------------------------------------------------------------------ helpers
func _frames(n: int) -> void:
	for _i in range(n):
		await tree.physics_frame


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _check(cond: bool, msg: String) -> bool:
	if not cond:
		printerr("[FAIL] ", msg)
	return cond


func _level() -> CampaignLevel:
	GameState.current_level = 1
	GameState.checkpoint_index = -1
	var level := CampaignLevel.new()
	level.level_number = 1
	tree.root.add_child(level)
	await _frames(80)       # spawn invulnerability wears off
	return level


func _unload(n: Node) -> void:
	tree.paused = false
	Engine.time_scale = 1.0
	for k in [KEY_S, KEY_J, KEY_L, KEY_W, KEY_H]:
		_key(k, false)
	n.queue_free()
	for p in tree.get_nodes_in_group("projectiles"):
		p.queue_free()
	await _frames(3)


## A fresh thug right in front of the player (player faces right, thug faces left).
func _thug(level: CampaignLevel, guard: float = 0.0) -> EnemyBase:
	var p := level.player
	p.global_position = Vector2(140, 300 - 16)
	p._set_facing(1.0)
	var e := level.builder.spawn_enemy({"type": "thug", "x": 162.0, "y": 300.0}) as EnemyBase
	e.guard_chance = guard
	await _frames(4)
	e.global_position = Vector2(162, e.global_position.y)
	e.facing_dir = -1.0
	e.state = EnemyBase.AIState.RECOVER
	e._state_timer = 5.0
	return e


func _strike_and_wait(e: EnemyBase, press_block_at: float) -> void:
	## Makes the thug telegraph + attack; presses block when `press_block_at` seconds of telegraph remain.
	e.start_telegraph()
	var pressed := press_block_at < 0.0
	if pressed:
		_key(KEY_S, true)
	for _i in range(120):
		if not pressed and e._state_timer <= press_block_at:
			_key(KEY_S, true)
			pressed = true
		await _frames(1)
		if e.state != EnemyBase.AIState.TELEGRAPH and e.state != EnemyBase.AIState.ATTACK:
			break


# ------------------------------------------------------------------ tests
func _test_block_and_parry() -> bool:
	var level := await _level()
	var p := level.player
	var e := await _thug(level)
	# early block (well before the hit) = chip damage, no hurt reaction
	_key(KEY_S, true)
	await _frames(30)
	var ok := _check(p.current_state == PlayerController.State.BLOCKING, "holding S on the ground enters BLOCKING (state=%s)" % PlayerController.State.keys()[p.current_state])
	var hp0 := p.health_component.current_health
	await _strike_and_wait(e, -1.0)
	var lost := hp0 - p.health_component.current_health
	ok = ok and _check(lost > 0 and lost <= 3 and p.current_state == PlayerController.State.BLOCKING, "blocked hit deals chip damage only (lost %d, state %s)" % [lost, PlayerController.State.keys()[p.current_state]])
	_key(KEY_S, false)
	await _frames(70)
	# timed block right before the strike = parry: no damage and the thug is stunned
	e.state = EnemyBase.AIState.RECOVER
	e._state_timer = 5.0
	p.health_component.is_invulnerable = false
	hp0 = p.health_component.current_health
	var meter0 := p.power_meter
	e.start_telegraph()
	var parried := false
	for _i in range(90):
		if e.state == EnemyBase.AIState.TELEGRAPH and e._state_timer <= 0.08 and not Input.is_action_pressed("climb_down"):
			_key(KEY_S, true)
		await _frames(1)
		if int(p.stats.get("parries", 0)) > 0:
			parried = true
			break
	await _frames(2)
	ok = ok and _check(parried and p.health_component.current_health == hp0, "a block pressed just before the strike parries it (parries=%d hp %d->%d)" % [int(p.stats.get("parries", 0)), hp0, p.health_component.current_health])
	ok = ok and _check(e.state == EnemyBase.AIState.HURT and p.power_meter > meter0, "parry stuns the attacker and grants meter")
	_key(KEY_S, false)
	await _unload(level)
	if ok:
		print("[PASS] block (chip only) and timed parry (stun + meter) with real S key events")
	return ok


func _test_heavy_and_guard_break() -> bool:
	var level := await _level()
	var p := level.player
	var e := await _thug(level, 1.0)
	var hp0 := e.health_component.current_health
	_key(KEY_J, true)
	await _frames(2)
	_key(KEY_J, false)
	await _frames(20)
	var ok := _check(e.health_component.current_health == hp0, "a guarding thug blocks a light jab (hp %d->%d)" % [hp0, e.health_component.current_health])
	await _frames(30)
	_key(KEY_J, true)
	var saw_heavy := false
	for _i in range(40):
		await _frames(1)
		if p._pending_attack_id == "heavy":
			saw_heavy = true
	_key(KEY_J, false)
	await _frames(30)
	ok = ok and _check(saw_heavy, "holding J converts the jab into a HEAVY")
	ok = ok and _check(e.health_component.current_health < hp0, "the heavy breaks the guard and deals damage (hp %d->%d)" % [hp0, e.health_component.current_health])
	await _unload(level)
	if ok:
		print("[PASS] hold-J heavy attack and enemy guard / guard break")
	return ok


func _test_specials() -> bool:
	var level := await _level()
	var p := level.player
	var ok := _check(p.power_meter == PlayerController.METER_START, "the run starts with one bar of power")
	var e := await _thug(level)
	# SP2 with W + L
	p.set_meter(200.0)
	_key(KEY_W, true)
	_key(KEY_L, true)
	await _frames(2)
	_key(KEY_L, false)
	_key(KEY_W, false)
	ok = ok and _check(p._pending_attack_id == "sp2_whirl" and p.power_meter == 0.0, "W+L with 2 bars performs WEB WHIRLWIND (id=%s meter=%.0f)" % [p._pending_attack_id, p.power_meter])
	await _frames(80)
	# SP3 with S + L at full meter: cinematic camera + multi-hit + launcher
	p.set_meter(300.0)
	e = await _thug(level)
	e.health_component.max_health = 400
	e.health_component.reset_health()
	var hp0 := e.health_component.current_health
	var hits0 := int(p.stats.get("hits", 0))
	_key(KEY_S, true)
	await _frames(3)
	_key(KEY_L, true)
	await _frames(2)
	_key(KEY_L, false)
	_key(KEY_S, false)
	ok = ok and _check(p._pending_attack_id.begins_with("sp3") and p.power_meter == 0.0, "S+L with 3 bars performs MAXIMUM SPIDER")
	ok = ok and _check(level.camera_director.is_cinematic(), "SP3 triggers the cinematic camera push-in")
	await _frames(100)
	var hits := int(p.stats.get("hits", 0)) - hits0
	ok = ok and _check(hits >= 3 and (e.health_component.current_health < hp0 or e.is_defeated()), "SP3 lands multiple hits (%d)" % hits)
	ok = ok and _check(int(p.stats.get("specials", 0)) == 2, "specials are counted for scoring")
	await _unload(level)
	if ok:
		print("[PASS] power meter specials: SP2 (W+L) and cinematic multi-hit SP3 (S+L)")
	return ok


func _test_scoring_and_economy() -> bool:
	var great := Scoring.evaluate({"hits": 80, "max_combo": 22, "parries": 4, "specials": 3, "damage_taken": 10}, 120.0, 200.0)
	var poor := Scoring.evaluate({"hits": 10, "max_combo": 3, "parries": 0, "specials": 0, "damage_taken": 200}, 500.0, 200.0)
	var ok := _check(great["rank"] == "S" and int(great["stars"]) == 3, "a fast, clean, stylish run ranks S with 3 stars")
	ok = ok and _check(poor["rank"] in ["D", "C"] and int(poor["stars"]) == 1, "a slow, messy run ranks low with 1 star")
	ok = ok and _check(int(great["tokens"]) > int(poor["tokens"]), "better runs pay more tokens")
	GameState.reset_progress()
	GameState.add_tokens(1000)
	var cost := GameState.upgrade_cost("strength")
	ok = ok and _check(GameState.buy_upgrade("strength") and GameState.get_upgrade("strength") == 1 and GameState.tokens == 1000 - cost, "buying an upgrade spends tokens and raises its level")
	ok = ok and _check(GameState.buy_suit("midnight") and GameState.owns_suit("midnight"), "a suit can be bought")
	GameState.equip_suit("midnight")
	ok = ok and _check(not GameState.buy_suit("arctic"), "an unaffordable suit cannot be bought")
	ok = ok and _check(GameState.record_chapter_result(1, 5000, "A", 3) and not GameState.record_chapter_result(1, 4000, "B", 2), "only a higher score is a new best")
	ok = ok and _check(GameState.chapter_rank[1] == "A" and GameState.chapter_stars[1] == 3, "best rank and stars are kept")
	GameState.save_game()
	GameState.tokens = 0
	GameState.upgrades = {}
	GameState.load_game()
	ok = ok and _check(GameState.get_upgrade("strength") == 1 and GameState.suit_equipped == "midnight" and GameState.tokens > 0, "economy persists through save/load")
	var level := await _level()
	ok = ok and _check(level.player.damage_mult > 1.0 and level.player.suit_key == "midnight" and level.player.sprite.material != null, "upgrades and the equipped suit apply in a chapter")
	await _unload(level)
	GameState.reset_progress()
	if ok:
		print("[PASS] scoring ranks/stars, tokens, upgrades, suits and persistence")
	return ok


func _arena(mode: String, tier: int = 1) -> ArenaLevel:
	var a := ArenaLevel.new()
	a.mode = mode
	a.tier = tier
	tree.root.add_child(a)
	await _frames(10)
	return a


func _kill_all(a: ArenaLevel) -> void:
	for n in a._alive.duplicate():
		if not is_instance_valid(n):
			continue
		var hc: HealthComponent = n.get("health_component")
		if hc != null and not hc.is_dead:
			hc.is_invulnerable = false
			hc.take_damage(99999, Vector2.ZERO, "test")
	await _frames(4)


func _test_gauntlet() -> bool:
	var a := await _arena("gauntlet", 1)
	var tokens0 := GameState.tokens
	var ok := true
	for r in range(ArenaLevel.GAUNTLET_ROUNDS.size()):
		var waited := 0
		while a._alive.is_empty() and waited < 400:
			await _frames(5)
			waited += 5
		ok = ok and _check(not a._alive.is_empty(), "gauntlet round %d spawns its fighters" % (r + 1))
		if not ok:
			break
		await _frames(20)
		await _kill_all(a)
		await _frames(10)
	var waited := 0
	while not a.finished and waited < 600:
		await _frames(10)
		waited += 10
	ok = ok and _check(a.finished and int(GameState.arena_best.get("gauntlet", 0)) == 1, "clearing all four rounds clears tier 1")
	ok = ok and _check(GameState.tokens > tokens0 and a.last_result.has("rank"), "the gauntlet pays tokens and is ranked")
	await _unload(a)
	if ok:
		print("[PASS] Gauntlet: four rounds (squad, Thief, Brick, Goblin), tier record and tokens")
	return ok


func _test_survival() -> bool:
	var a := await _arena("survival")
	var ok := true
	for w in range(3):
		var waited := 0
		while a._alive.is_empty() and waited < 400:
			await _frames(5)
			waited += 5
		await _frames(10)
		await _kill_all(a)
		await _frames(10)
	var waited := 0
	while a.wave < 4 and waited < 400:
		await _frames(5)
		waited += 5
	ok = ok and _check(a.wave == 4, "survival advances wave by wave (wave=%d)" % a.wave)
	var hc := a.player.health_component
	hc.is_invulnerable = false
	hc.take_damage(9999, Vector2.ZERO, "test")
	waited = 0
	while not a.finished and waited < 300:
		await _frames(10)
		waited += 10
	ok = ok and _check(a.finished and int(GameState.arena_best.get("survival", 0)) == 3, "defeat ends the run and records the best wave (%d)" % int(GameState.arena_best.get("survival", 0)))
	await _unload(a)
	if ok:
		print("[PASS] Survival: escalating waves, run ends on defeat, best wave recorded")
	return ok
