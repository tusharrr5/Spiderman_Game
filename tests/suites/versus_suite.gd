extends RefCounted
## Versus-mode regression suite: the 20-fighter roster and its art, the bot AI at every difficulty (it
## fights, blocks, parries and scales), 1v1 and 3v3 elimination, tagging, the round timer, focus charge,
## blast specials, CPU vs CPU, records/tokens, the title / setup / fighter-select menus, key rebinding,
## and the fight systems: 5-hit chain, buffs/debuffs, class triangle, boosts, synergies, levels, challenges.

var tree: SceneTree


func run(p_tree: SceneTree) -> bool:
	tree = p_tree
	Fx.hitstop_enabled = false
	GameState.save_path = "user://test_savegame.cfg"
	GameState.routing_enabled = false
	GameState.seen_controls_guide = true
	GameState.reset_progress()
	print("=== VERSUS SUITE ===")
	for t in [_test_roster, _test_every_fighter_spawns, _test_1v1_bot_fights_and_win, _test_difficulty_scaling,
			_test_bot_defends, _test_3v3_elimination_and_tag, _test_timer, _test_charge_and_blast, _test_cpu_vs_cpu,
			_test_menus, _test_key_rebinding, _test_five_hit_chain_and_effects, _test_class_boosts_synergy,
			_test_progression]:
		if not await t.call():
			return false
	GameState.reset_progress()
	GameState.routing_enabled = true
	GameState.save_path = "user://savegame.cfg"
	GameState.load_game()
	print("=== VERSUS SUITE PASSED ===")
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


func _match(cfg: Dictionary) -> VersusLevel:
	var v := VersusLevel.new()
	v.config = cfg
	tree.root.add_child(v)
	await _frames(100)          # intro: ROUND 1 ... FIGHT!
	return v


func _unload(n: Node) -> void:
	tree.paused = false
	Engine.time_scale = 1.0
	for k in [KEY_J, KEY_L, KEY_S, KEY_C, KEY_D]:
		_key(k, false)
	n.queue_free()
	for p in tree.get_nodes_in_group("projectiles"):
		p.queue_free()
	await _frames(3)


func _ko(f: PlayerController) -> void:
	f.health_component.is_invulnerable = false
	f.health_component.take_damage(99999, Vector2.ZERO, "test")


func _wait(cond: Callable, max_frames: int) -> bool:
	var n := 0
	while not cond.call() and n < max_frames:
		await _frames(5)
		n += 5
	return cond.call()


# ------------------------------------------------------------------ tests
func _test_roster() -> bool:
	var ok := _check(SpiderRoster.ORDER.size() == 20 and SpiderRoster.DATA.size() == 20, "the roster has 20 fighters")
	var seen := {}
	for k in SpiderRoster.ORDER:
		var i := SpiderRoster.info(k)
		seen[k] = true
		ok = ok and _check(SpriteDB.SHEETS.has(String(i["sheet"])), "%s has a sprite sheet" % k)
		ok = ok and _check(load(SpriteDB.SHEETS[String(i["sheet"])]["path"]) is Texture2D, "%s sheet loads" % k)
		ok = ok and _check(load(String(i["portrait"])) is Texture2D, "%s portrait loads" % k)
		ok = ok and _check((i["specials"] as Array).size() == 3 and SpiderRoster.PASSIVES.has(String(i["passive"])), "%s has 3 specials and a valid passive" % k)
		for anim in ["idle", "run", "jab", "heavy", "block", "sp_flurry", "victory", "defeated"]:
			ok = ok and _check((SpriteDB.SHEETS[String(i["sheet"])]["anims"] as Dictionary).has(anim), "%s sheet has %s" % [k, anim])
	ok = ok and _check(seen.size() == 20, "roster keys are unique")
	if ok:
		print("[PASS] roster: 20 unique fighters with sheets, portraits, full moveset, 3 specials and a passive each")
	return ok


func _test_every_fighter_spawns() -> bool:
	var ok := true
	var keys := SpiderRoster.ORDER
	for i in range(0, keys.size(), 2):
		var v := await _match({"mode": "1v1", "difficulty": "easy", "stage": "street_dusk", "team1": [keys[i]], "team2": [keys[i + 1]]})
		for t in [1, 2]:
			var f: PlayerController = v.active[t]
			var info := SpiderRoster.info(String(v.teams[t][0]))
			ok = ok and _check(f != null and f.character_key == info["key"] and f.health_component.max_health == int(round(float(info["hp"]) * VersusLevel.HP_SCALE)), "%s spawns with its stats" % info["key"])
			ok = ok and _check(f.sprite.texture.resource_path == SpriteDB.SHEETS[String(info["sheet"])]["path"], "%s uses its own art" % info["key"])
			ok = ok and _check(f.is_in_group("team%d" % t) and (f.is_bot == (t == 2)), "%s is on team %d" % [info["key"], t])
		await _unload(v)
		if not ok:
			return false
	print("[PASS] all 20 fighters spawn with their own art, stats and team setup")
	return ok


func _test_1v1_bot_fights_and_win() -> bool:
	var tokens0 := GameState.tokens
	var v := await _match({"mode": "1v1", "difficulty": "moderate", "stage": "random", "team1": ["miles"], "team2": ["noir"], "ai_seed": 3})
	var human: PlayerController = v.active[1]
	var bot: PlayerController = v.active[2]
	var ok := _check(not human.is_bot and human.is_in_group("player") and not bot.is_in_group("player"), "only the human fighter receives player input")
	var hp0 := human.health_component.current_health
	var ai: FighterAI = bot.controller
	ok = ok and await _wait(func() -> bool: return human.health_component.current_health < hp0, 900)
	ok = ok and _check(int(ai.stats["attacks"]) > 0, "the bot approaches and lands attacks on a standing player (hp %d -> %d)" % [hp0, human.health_component.current_health])
	# real J presses damage the bot
	human.global_position = bot.global_position - Vector2(22, 0)
	human._set_facing(1.0)
	var bhp := bot.health_component.current_health
	for _i in range(4):
		_key(KEY_J, true)
		await _frames(2)
		_key(KEY_J, false)
		await _frames(10)
	ok = ok and _check(bot.health_component.current_health < bhp or int(ai.stats["blocks_started"]) > 0, "real J presses hit the bot (or it blocks)")
	_ko(bot)
	ok = ok and await _wait(func() -> bool: return v.finished, 400)
	ok = ok and _check(v.winner == 1 and GameState.tokens > tokens0, "knocking out the bot wins the 1v1 and pays tokens")
	ok = ok and _check(int(GameState.versus_stats.get("wins", 0)) == 1 and int(GameState.char_wins.get("miles", 0)) == 1, "the win is recorded for the player and the fighter")
	await _frames(150)
	ok = ok and _check(v.hud.get_node("RootControl").find_child("Rematch", true, false) != null, "results offer REMATCH / NEW FIGHTERS / MENU")
	await _unload(v)
	if ok:
		print("[PASS] 1v1: bot fights back, real keys hit it, KO wins, tokens + records + rematch menu")
	return ok


## Same fighters, same seed, a passive player: harder bots deal more damage in the same time.
func _bot_damage(diff: String) -> int:
	var v := await _match({"mode": "1v1", "difficulty": diff, "stage": "street_dusk", "team1": ["classic"], "team2": ["classic"], "ai_seed": 11})
	var human: PlayerController = v.active[1]
	human.health_component.max_health = 5000
	human.health_component.reset_health()
	await _frames(720)
	var dealt := 5000 - human.health_component.current_health
	await _unload(v)
	return dealt


func _test_difficulty_scaling() -> bool:
	var easy := await _bot_damage("easy")
	var hard := await _bot_damage("more_difficult")
	var mid := await _bot_damage("moderate")
	var diff := await _bot_damage("difficult")
	print("    bot damage to a passive player in 12s: easy %d, moderate %d, difficult %d, more difficult %d" % [easy, mid, diff, hard])
	var ok := _check(hard > easy and hard > 0 and diff > easy, "harder bots deal more damage in 12s (%d / %d / %d / %d)" % [easy, mid, diff, hard])
	ok = ok and _check(hard < 160 * 3, "even MORE DIFFICULT leaves a passive player alive for several seconds (%d dmg / 12s)" % hard)
	ok = ok and _check(FighterAI.LEVELS.size() == 4 and FighterAI.NAMES["more_difficult"] == "MORE DIFFICULT", "four difficulty levels exist")
	if ok:
		print("[PASS] difficulty: easy -> more difficult scales bot damage (%d -> %d)" % [easy, hard])
	return ok


func _defense(diff: String) -> Dictionary:
	var v := await _match({"mode": "1v1", "difficulty": diff, "stage": "street_dusk", "team1": ["classic"], "team2": ["noir"], "ai_seed": 5})
	var human: PlayerController = v.active[1]
	var bot: PlayerController = v.active[2]
	bot.health_component.max_health = 5000
	bot.health_component.reset_health()
	human.health_component.grant_invulnerability(999.0)
	var ai: FighterAI = bot.controller
	ai.p = ai.p.duplicate()                   # measure reactions only: no offence from the bot
	ai.p["aggr"] = 0.0
	ai.p["special"] = 0.0
	ai.p["guard"] = 0.0
	for _i in range(20):
		human.global_position = bot.global_position - Vector2(24, 0)
		human._set_facing(1.0)
		_key(KEY_J, true)
		await _frames(24)                   # held -> heavy (parryable wind-up)
		_key(KEY_J, false)
		await _frames(24)
	var out := {"blocks": int(bot.stats.get("blocks", 0)), "parries": int(bot.stats.get("parries", 0))}
	await _unload(v)
	return out


func _test_bot_defends() -> bool:
	var easy := await _defense("easy")
	var hard := await _defense("more_difficult")
	var ok := _check(int(hard["blocks"]) + int(hard["parries"]) > int(easy["blocks"]) + int(easy["parries"]), "harder bots guard more (easy %s vs hard %s)" % [easy, hard])
	ok = ok and _check(int(hard["parries"]) > 0, "a MORE DIFFICULT bot parries telegraphed heavies (%s)" % hard)
	if ok:
		print("[PASS] bot defence: MORE DIFFICULT blocks/parries %s vs EASY %s" % [hard, easy])
	return ok


func _test_3v3_elimination_and_tag() -> bool:
	var v := await _match({"mode": "3v3", "difficulty": "easy", "stage": "night_industrial", "team1": ["miles", "gwen", "peni"], "team2": ["noir", "ham", "2099"]})
	var ok := _check(v.slots[1].size() == 3 and v.slots[2].size() == 3, "3v3 builds two teams of three")
	# tag with the real C key (the bot is frozen so the tag isn't refused mid hit-stun)
	(v.active[2] as PlayerController).input_locked = true
	await _wait(func() -> bool: return (v.active[1] as PlayerController).current_state != PlayerController.State.HURT, 120)
	var first := (v.active[1] as PlayerController).character_key
	_key(KEY_C, true)
	await _frames(3)
	_key(KEY_C, false)
	await _frames(5)
	ok = ok and _check((v.active[1] as PlayerController).character_key != first and v.tag_cd[1] > 0.0, "C tags in the next teammate")
	ok = ok and _check(not v.tag(1), "tag has a cooldown")
	# knock out the bot team one by one
	for i in range(3):
		var b: PlayerController = v.active[2]
		var key := b.character_key
		_ko(b)
		if i < 2:
			ok = ok and await _wait(func() -> bool: return is_instance_valid(v.active[2]) and (v.active[2] as PlayerController).character_key != key and not v.paused_flow, 400)
			ok = ok and _check(not bool(v.slots[2][i]["alive"]), "KO'd bot fighter %d is eliminated and the next one enters" % (i + 1))
	ok = ok and await _wait(func() -> bool: return v.finished, 400)
	ok = ok and _check(v.winner == 1, "defeating all three bot fighters wins the 3v3")
	await _unload(v)
	# the player's team can lose too
	v = await _match({"mode": "3v3", "difficulty": "easy", "stage": "storm_finale", "team1": ["byte", "uk", "iron"], "team2": ["jess", "punk", "india"]})
	for i in range(3):
		var f: PlayerController = v.active[1]
		var key := f.character_key
		_ko(f)
		if i < 2:
			await _wait(func() -> bool: return is_instance_valid(v.active[1]) and (v.active[1] as PlayerController).character_key != key and not v.paused_flow, 400)
	ok = ok and await _wait(func() -> bool: return v.finished, 400)
	ok = ok and _check(v.winner == 2 and int(GameState.versus_stats.get("losses", 0)) >= 1, "losing all three player fighters loses the 3v3")
	await _unload(v)
	if ok:
		print("[PASS] 3v3: real C-key tag + cooldown, fighter-by-fighter elimination, win and loss")
	return ok


func _test_timer() -> bool:
	var v := await _match({"mode": "1v1", "difficulty": "easy", "stage": "street_dusk", "team1": ["advanced"], "team2": ["bagman"]})
	var bot: PlayerController = v.active[2]
	bot.health_component.current_health = 20
	v.bout_time = 0.05
	var ok := await _wait(func() -> bool: return v.finished, 400)
	ok = _check(ok and v.winner == 1, "time-out knocks out the fighter with less health")
	await _unload(v)
	if ok:
		print("[PASS] 99s round timer: time-out decides the bout on health")
	return ok


func _test_charge_and_blast() -> bool:
	var v := await _match({"mode": "1v1", "difficulty": "easy", "stage": "street_dusk", "team1": ["miles"], "team2": ["peter_b"]})
	var human: PlayerController = v.active[1]
	var bot: PlayerController = v.active[2]
	bot.set_physics_process(false)             # the bot stands still for this test
	bot.global_position.x = human.global_position.x + 200.0
	await _wait(func() -> bool: return human.current_state == PlayerController.State.IDLE, 180)
	human.set_meter(0.0)
	_key(KEY_L, true)
	await _frames(40)
	var charging := human.current_state == PlayerController.State.CHARGING
	_key(KEY_L, false)
	await _frames(4)
	var ok := _check(charging and human.power_meter > 20.0, "holding L with no power focus-charges the meter (%.0f)" % human.power_meter)
	human.set_meter(100.0)
	await _wait(func() -> bool: return human.current_state == PlayerController.State.IDLE, 120)
	human.global_position = Vector2(bot.global_position.x - 120.0, human.global_position.y)
	human._set_facing(1.0)
	var hp0 := bot.health_component.current_health
	_key(KEY_L, true)
	await _frames(2)
	_key(KEY_L, false)
	ok = ok and await _wait(func() -> bool: return bot.health_component.current_health < hp0, 120)
	ok = _check(ok and human.power_meter < 100.0, "Miles' 1-bar special is a ranged blast that hits from 120px away")
	await _unload(v)
	if ok:
		print("[PASS] focus charge (hold L) and ranged blast special")
	return ok


func _test_cpu_vs_cpu() -> bool:
	var v := await _match({"mode": "cpu", "difficulty": "more_difficult", "stage": "goblin_facility", "team1": ["symbiote"], "team2": ["scarlet"], "cpu_vs_cpu": true, "ai_seed": 9})
	var ok := _check((v.active[1] as PlayerController).is_bot and (v.active[2] as PlayerController).is_bot, "CPU VS CPU drives both teams with bots")
	for t in [1, 2]:
		var f: PlayerController = v.active[t]
		f.health_component.max_health = 60
		f.health_component.reset_health()
	ok = ok and await _wait(func() -> bool: return v.finished, 3600)
	ok = _check(ok and v.winner in [1, 2], "two bots fight a match to a finish on their own")
	await _unload(v)
	if ok:
		print("[PASS] CPU VS CPU: bots fight each other to a KO")
	return ok


func _test_menus() -> bool:
	var title: Control = load("res://scenes/menus/title_screen.tscn").instantiate()
	tree.root.add_child(title)
	await _frames(3)
	var ok := _check(title.find_child("StoryButton", true, false) != null and title.find_child("VersusButton", true, false) != null, "title has STORY MODE and VERSUS")
	(title.find_child("StoryButton", true, false) as Button).pressed.emit()
	await _frames(2)
	ok = ok and _check((title.get_node("StoryMenu") as Control).visible and title.find_child("NewGameButton", true, false) != null, "STORY MODE opens the campaign menu")
	(title.find_child("VersusButton", true, false) as Button).pressed.emit()
	ok = ok and _check(GameState.last_route == GameState.VERSUS_SETUP_SCENE, "VERSUS opens versus setup")
	title.queue_free()
	var setup: Control = load("res://scenes/menus/versus_setup.tscn").instantiate()
	tree.root.add_child(setup)
	await _frames(3)
	(setup.find_child("Mode_3v3", true, false) as Button).pressed.emit()
	(setup.find_child("Diff_more_difficult", true, false) as Button).pressed.emit()
	(setup.find_child("Next", true, false) as Button).pressed.emit()
	await _frames(2)
	for k in ["miles", "gwen", "noir"]:
		(setup.find_child("Pick_" + k, true, false) as Button).pressed.emit()
	await _frames(2)
	var fight := setup.find_child("Fight", true, false) as Button
	ok = ok and _check(not fight.disabled, "picking three fighters enables FIGHT in 3v3")
	fight.pressed.emit()
	await _frames(90)
	var cfg := GameState.versus_config
	ok = ok and _check(cfg.get("mode") == "3v3" and cfg.get("difficulty") == "more_difficult" and (cfg["team1"] as Array) == ["miles", "gwen", "noir"], "setup stores mode, difficulty and the player's team")
	var bot: Array = cfg["team2"]
	ok = ok and _check(bot.size() == 3 and bot.all(func(k: String) -> bool: return SpiderRoster.DATA.has(k) and not k in ["miles", "gwen", "noir"]), "the bot drafts 3 different fighters from the roster (%s)" % [bot])
	ok = ok and _check(GameState.last_route == GameState.VERSUS_SCENE, "FIGHT starts the versus match")
	setup.queue_free()
	await _frames(3)
	if ok:
		print("[PASS] menus: title Story/Versus split, setup (mode, difficulty), fighter select, bot draft")
	return ok


func _test_key_rebinding() -> bool:
	var prev_path := KeyBindings.save_path
	KeyBindings.save_path = "user://test_keybinds.cfg"
	KeyBindings.reset_defaults()
	var ok := _check(KeyBindings.get_key("web_action", 0) == KEY_K, "web shot defaults to K")
	# Q for web shot: the action fires on Q and no longer on K
	KeyBindings.set_key("web_action", 0, KEY_Q)
	var q := InputEventKey.new()
	q.keycode = KEY_Q
	q.physical_keycode = KEY_Q
	q.pressed = true
	var k := InputEventKey.new()
	k.keycode = KEY_K
	k.physical_keycode = KEY_K
	k.pressed = true
	ok = ok and _check(InputMap.event_is_action(q, "web_action") and not InputMap.event_is_action(k, "web_action"), "web shot is now on Q, not K")
	# taking a key another action uses swaps them, so no key is bound twice
	var moved := KeyBindings.set_key("attack_punch", 0, KEY_Q)
	ok = ok and _check(moved == "Web shot / Swing" and KeyBindings.get_key("web_action", 0) == KEY_J, "binding Q to punch swaps J onto web shot (%s)" % moved)
	ok = ok and _check(KeyBindings.fill("press {punch} then {web}") == "press Q then J", "hint text shows the new keys (%s)" % KeyBindings.fill("press {punch} then {web}"))
	# saved and restored
	KeyBindings.load_and_apply()
	ok = ok and _check(KeyBindings.get_key("attack_punch", 0) == KEY_Q, "bindings persist across a reload")
	# a real Q key press now punches in game
	var v := await _match({"mode": "1v1", "difficulty": "easy", "stage": "street_dusk", "team1": ["classic"], "team2": ["noir"]})
	(v.active[2] as PlayerController).input_locked = true
	var human: PlayerController = v.active[1]
	await _wait(func() -> bool: return human.current_state == PlayerController.State.IDLE, 120)
	_key(KEY_Q, true)
	await _frames(2)
	_key(KEY_Q, false)
	await _frames(2)
	ok = ok and _check(human.current_state == PlayerController.State.ATTACKING, "the rebound Q key punches (state %s)" % PlayerController.State.keys()[human.current_state])
	await _unload(v)
	# the settings screen
	var panel := KeyBindPanel.new()
	tree.root.add_child(panel)
	panel.open()
	await _frames(2)
	ok = ok and _check(panel.visible and (panel.find_child("Key_attack_punch_0", true, false) as Button).text == "Q", "settings screen lists the current keys")
	(panel.find_child("Key_jump_1", true, false) as Button).emit_signal("pressed")
	_key(KEY_X, true)
	_key(KEY_X, false)
	await _frames(2)
	ok = ok and _check(KeyBindings.get_key("jump", 1) == KEY_X and (panel.find_child("Key_jump_1", true, false) as Button).text == "X", "clicking a slot and pressing X rebinds it")
	(panel.find_child("ResetKeys", true, false) as Button).emit_signal("pressed")
	await _frames(2)
	ok = ok and _check(KeyBindings.is_default() and KeyBindings.get_key("attack_punch", 0) == KEY_J, "RESET DEFAULTS restores J / K")
	panel.queue_free()
	# back to default keys; never load the player's real user://keybinds.cfg inside the test run
	KeyBindings.reset_defaults()
	KeyBindings.save_path = prev_path
	if ok:
		print("[PASS] key rebinding: Q for web/punch, swap on conflict, saved, real key press, settings screen, reset")
	return ok


func _test_five_hit_chain_and_effects() -> bool:
	var v := await _match({"mode": "1v1", "difficulty": "easy", "stage": "street_dusk", "team1": ["gwen"], "team2": ["peter_b"]})
	var human: PlayerController = v.active[1]
	var bot: PlayerController = v.active[2]
	bot.input_locked = true
	bot.health_component.max_health = 5000
	bot.health_component.reset_health()
	var ok := _check(human.long_combo and human.effects != null, "versus fighters use the 5-hit chain and status effects")
	await _wait(func() -> bool: return not human.input_locked and human.current_state == PlayerController.State.IDLE, 200)
	var seen: Array = []
	for i in range(5):
		human.global_position = bot.global_position - Vector2(22, 0)
		human._set_facing(1.0)
		bot.health_component.is_invulnerable = false
		_key(KEY_J, true)
		await _frames(1)
		_key(KEY_J, false)
		await _frames(10)
		seen.append(human._pending_attack_id)
	ok = ok and _check(seen == ["jab_1", "cross_2", "hook_3", "roundhouse_4", "spider_finisher"], "J x5 runs jab, cross, hook, roundhouse, finisher (%s)" % [seen])
	await _frames(20)
	ok = ok and _check(human.effects.has("fury") and int(human.stats.get("five_hit", 0)) == 1, "landing the 5th hit grants FURY (%s)" % [human.effects.active.keys()])
	ok = ok and _check(human.out_mult() > 1.1, "fury raises outgoing damage (x%.2f)" % human.out_mult())
	# heavy inflicts Gwen's signature debuff (BLEED), which ticks damage over time
	await _wait(func() -> bool: return human.current_state == PlayerController.State.IDLE, 120)
	human.global_position = bot.global_position - Vector2(22, 0)
	bot.health_component.is_invulnerable = false
	_key(KEY_J, true)
	await _frames(26)
	_key(KEY_J, false)
	await _frames(30)
	var sig := String(SpiderRoster.SIG["gwen"][0])
	ok = ok and _check(bot.effects.has(sig), "a heavy inflicts the signature debuff %s (%s)" % [sig, bot.effects.active.keys()])
	var hp := bot.health_component.current_health
	await _frames(90)
	ok = ok and _check(bot.health_component.current_health < hp, "BLEED drains health over time (%d -> %d)" % [hp, bot.health_component.current_health])
	ok = ok and _check(v.vhud._sides[1]["fx_chips"].has(sig), "the HUD shows the debuff icon")
	# SP1 grants the signature buff
	human.set_meter(100.0)
	await _wait(func() -> bool: return human.current_state == PlayerController.State.IDLE, 120)
	_key(KEY_L, true)
	await _frames(2)
	_key(KEY_L, false)
	await _frames(10)
	ok = ok and _check(human.effects.has(String(SpiderRoster.SIG["gwen"][1])), "SP1 grants the signature buff")
	await _unload(v)
	if ok:
		print("[PASS] 5-hit chain -> FURY, heavy -> signature debuff with damage over time, SP1 -> buff, HUD icons")
	return ok


func _test_class_boosts_synergy() -> bool:
	var ok := _check(SpiderRoster.advantage("miles", "india") == 1 and SpiderRoster.advantage("india", "miles") == -1, "SCIENCE beats MYSTIC")
	ok = ok and _check(SpiderRoster.class_mult("noir", "miles") > 1.0 and SpiderRoster.class_mult("miles", "noir") < 1.0, "SKILL beats SCIENCE")
	for k in SpiderRoster.ORDER:
		ok = ok and _check(SpiderRoster.CLASSES.has(k) and SpiderRoster.SIG.has(k), "%s has a class and signature ability" % k)
	ok = ok and _check(SpiderRoster.team_synergies(["miles", "gwen", "noir"]).any(func(s: Array) -> bool: return s[0] == "INTO THE SPIDER-VERSE"), "Miles + Gwen trigger INTO THE SPIDER-VERSE")
	GameState.boosts = {"attack": 1, "health": 1}
	var v := await _match({"mode": "3v3", "difficulty": "easy", "stage": "street_dusk", "team1": ["miles", "gwen", "noir"], "team2": ["india", "uk", "ham"],
		"boosts": ["attack", "health", "crit"]})
	var f: PlayerController = v.active[1]
	ok = ok and _check(v.team_boosts[1] == ["attack", "health"] and int(GameState.boosts["attack"]) == 0, "owned boosts are used up, missing ones ignored (%s)" % [v.team_boosts[1]])
	ok = ok and _check(is_equal_approx(f.boost_attack, 1.2) and f.health_component.max_health == int(round(100 * VersusLevel.HP_SCALE * 1.2)), "boosts raise attack and health")
	ok = ok and _check(f.power_meter >= PlayerController.METER_START + 100.0, "INTO THE SPIDER-VERSE starts the team with an extra bar (%.0f)" % f.power_meter)
	ok = ok and _check(f.incoming_mult(v.active[2]) < 1.0, "Miles (SCIENCE) takes less damage from a MYSTIC fighter")
	ok = ok and _check(String((v.vhud._sides[0]["class"] as Label).text).contains("SCIENCE"), "HUD shows the class badge")
	await _unload(v)
	if ok:
		print("[PASS] class triangle, signature abilities, boosts used up and applied, team synergies, class badge")
	return ok


func _test_progression() -> bool:
	GameState.reset_progress()
	var tokens0 := GameState.tokens
	GameState.record_versus(true, "more_difficult", ["miles"], false, {"parries": 3, "five_hit": 2})
	var rw := GameState.last_versus_rewards
	var ok := _check(int(rw["xp"]) > 0 and int(GameState.fighter_xp["miles"]) == int(rw["xp"]), "a win gives the fighter XP (%s)" % rw)
	ok = ok and _check("win1" in GameState.challenges_claimed and "hard1" in GameState.challenges_claimed and GameState.tokens > tokens0, "first win and MORE DIFFICULT challenges pay out")
	ok = ok and _check(GameState.challenge_value("parries") == 3, "fight stats feed challenge counters")
	for _i in range(10):
		GameState.record_versus(true, "difficult", ["miles"], false)
	ok = ok and _check(GameState.fighter_level("miles") > 1 and GameState.fighter_level_bonus("miles") > 0.0, "fighters level up (LV %d)" % GameState.fighter_level("miles"))
	var r1 := GameState.claim_daily_login()
	var r2 := GameState.claim_daily_login()
	ok = ok and _check(int(r1.get("tokens", 0)) > 0 and r2.is_empty(), "the daily reward pays once per day")
	GameState.tokens = 500
	var crit0 := int(GameState.boosts.get("crit", 0))
	ok = ok and _check(GameState.buy_boost("crit") and int(GameState.boosts["crit"]) == crit0 + 1 and GameState.tokens == 400, "boosts can be bought with tokens")
	GameState.save_game()
	GameState.load_game()
	ok = ok and _check(int(GameState.boosts["crit"]) == crit0 + 1 and GameState.fighter_level("miles") > 1 and GameState.login_day == GameState.today_key(), "boosts, levels and login day are saved")
	GameState.reset_progress()
	if ok:
		print("[PASS] progression: XP and levels, challenges, daily reward, boost shop, saved")
	return ok
