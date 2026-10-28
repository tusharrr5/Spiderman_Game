extends RefCounted
## Campaign regression suite: loads every chapter through CampaignLevel and verifies geometry, objectives,
## bosses (incl. the Chapter 3 scripted defeat and Chapter 5 three-phase finale), the rescue/escape flow,
## checkpoint respawn, retry-current-level, saving/unlocking and locked future chapters.
## Uses a scratch save file and disables scene routing so the player's real progress is never touched.

var tree: SceneTree


func run(p_tree: SceneTree) -> bool:
	tree = p_tree
	Fx.hitstop_enabled = false
	GameState.save_path = "user://test_savegame.cfg"
	GameState.routing_enabled = false
	GameState.seen_controls_guide = true
	GameState.reset_progress()
	print("=== CAMPAIGN SUITE ===")
	if not await _test_registry_and_saves():
		return false
	for n in range(1, LevelRegistry.PLAYABLE_LEVELS + 1):
		if not await _test_geometry(n):
			return false
	if not await _test_ch1():
		return false
	if not await _test_ch2():
		return false
	if not await _test_ch3_and_retry():
		return false
	if not await _test_ch4():
		return false
	if not await _test_ch5():
		return false
	GameState.routing_enabled = true
	GameState.save_path = "user://savegame.cfg"
	GameState.load_game()
	print("=== CAMPAIGN SUITE PASSED ===")
	return true


# ------------------------------------------------------------------ helpers
func _frames(n: int) -> void:
	for _i in range(n):
		await tree.physics_frame


func _load(n: int, cp: int = -1, cp_obj: int = 0) -> CampaignLevel:
	GameState.current_level = n
	GameState.checkpoint_index = cp
	GameState.checkpoint_objective = cp_obj
	var level := CampaignLevel.new()
	level.level_number = n
	tree.root.add_child(level)
	await _frames(12)
	return level


func _unload(level: CampaignLevel) -> void:
	tree.paused = false
	Engine.time_scale = 1.0
	level.queue_free()
	for p in tree.get_nodes_in_group("projectiles"):
		p.queue_free()
	await _frames(3)


func _floor_below(world: World2D, pos: Vector2, dist: float = 60.0) -> bool:
	var q := PhysicsRayQueryParameters2D.create(pos, pos + Vector2(0, dist), 1)
	return not world.direct_space_state.intersect_ray(q).is_empty()


func _teleport(level: CampaignLevel, pos: Vector2) -> void:
	level.player.global_position = pos
	level.player.velocity = Vector2.ZERO
	await _frames(6)


func _hurt(target: Node, amount: int) -> void:
	var hc: HealthComponent = target.get("health_component")
	hc.is_invulnerable = false
	if target.has_method("apply_combat_hit"):
		target.apply_combat_hit(amount, Vector2.ZERO, "test", 0.1)
	await _frames(2)


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


# ------------------------------------------------------------------ tests
func _test_registry_and_saves() -> bool:
	if not _check(LevelRegistry.get_level(6).is_empty() and not GameState.is_unlocked(6), "Future chapters must not be playable"):
		return false
	if not _check(GameState.is_unlocked(1) and not GameState.is_unlocked(2), "Fresh save unlocks only chapter 1"):
		return false
	GameState.complete_level(1, 100.0)
	GameState.complete_level(2, 200.0)
	GameState.highest_unlocked = 1
	GameState.completed = {}
	GameState.load_game()
	if not _check(GameState.highest_unlocked == 3 and GameState.is_completed(2) and GameState.is_unlocked(3), "Saved progress must reload (chapter 3 unlocked)"):
		return false
	GameState.reset_progress()
	print("[PASS] registry, locked future chapters, save/load and unlocking")
	return true


func _test_geometry(n: int) -> bool:
	var level := await _load(n)
	var w := level.get_world_2d()
	var ok := _check(level.player.is_on_floor(), "Ch%d: player must spawn on solid ground" % n)
	for c in level.data.get("checkpoints", []):
		ok = ok and _check(_floor_below(w, Vector2(c[0], float(c[1]) - 20.0)), "Ch%d: checkpoint at %s needs floor" % [n, str(c)])
	for e in tree.get_nodes_in_group("enemies"):
		var en := e as EnemyBase
		if en != null and not en.flying and not (en is BossBase):
			ok = ok and _check(_floor_below(w, en.global_position, en.body_size.y), "Ch%d: %s at %s must stand on a floor" % [n, en.sheet_key, str(en.global_position)])
	ok = ok and _check(level.objectives.size() > 0 and level.hud.objective_label.text != "", "Ch%d: objectives must be shown" % n)
	# a short real run: holding D moves the hero right without falling out of the level
	var x0 := level.player.global_position.x
	_key(KEY_D, true)
	await _frames(40)
	_key(KEY_D, false)
	await _frames(10)
	ok = ok and _check(level.player.global_position.x > x0 + 20.0 and not level.failed, "Ch%d: hero must run right from spawn" % n)
	await _unload(level)
	if ok:
		print("[PASS] Ch%d geometry, spawn, checkpoints, enemy placement and running" % n)
	return ok


func _test_ch1() -> bool:
	var level := await _load(1)
	# real input combat: stand beside the first thug and press J
	var thug: EnemyBase = null
	for e in tree.get_nodes_in_group("enemies"):
		if e is NormalEnemy:
			thug = e
			break
	await _teleport(level, thug.global_position + Vector2(-14, -2))
	level.player.facing_dir = 1.0
	var hp0 := thug.health_component.current_health
	_key(KEY_J, true)
	await _frames(4)
	_key(KEY_J, false)
	await _frames(14)
	if not _check(thug.health_component.current_health < hp0, "Ch1: J punch must damage an adjacent thug"):
		return false
	await _teleport(level, Vector2(1740, 230 - 16))
	if not _check(level.obj_index == 1, "Ch1: reaching the far rooftop completes objective 1"):
		return false
	# an enemy knocked into a pit must count as defeated so objectives can never soft-lock
	var faller := tree.get_nodes_in_group("gang")[0] as EnemyBase
	faller.global_position = Vector2(faller.global_position.x, (level.data["bounds"] as Rect2).end.y + 20.0)
	await _frames(4)
	if not _check(faller.is_defeated(), "Ch1: an enemy that falls out of the level counts as defeated"):
		return false
	for e in tree.get_nodes_in_group("gang"):
		if not (e as EnemyBase).is_defeated():
			await _hurt(e, 999)
	await _frames(4)
	if not _check(level.obj_index == 2, "Ch1: defeating the gang completes objective 2"):
		return false
	await _teleport(level, Vector2(2600, 300 - 16))
	await _frames(10)
	if not _check(level.obj_index == 3 and (level.builder.boss as PrototypeBoss)._engaged, "Ch1: Brick must engage in the arena"):
		return false
	var brick := level.builder.boss as PrototypeBoss
	var guard := 0
	while not brick.health_component.is_dead and guard < 80:
		await _hurt(brick, 30)
		await _frames(6)
		guard += 1
	await _frames(200)
	var ok := _check(level.completed and GameState.is_completed(1) and GameState.is_unlocked(2), "Ch1: defeating Brick completes the chapter and unlocks Ch2")
	ok = ok and _check(GameState.last_route == GameState.STORY_SCENE and GameState.story_next == "level:2", "Ch1: completion routes to the outro story then Ch2")
	await _unload(level)
	if ok:
		print("[PASS] Ch1 real punch, objectives, Brick fight and completion")
	return ok


func _test_ch2() -> bool:
	var level := await _load(2)
	var th := level.builder.boss as ThiefBoss
	# chase him for real: the hero keeps pace 140px behind, the thief must run & jump his whole route himself
	var frames := 0
	var lowest := -9999.0
	while not level._flags.has("thief_cornered") and frames < 60 * 45:
		if frames % 20 == 0:
			level.player.global_position = th.global_position + Vector2(-140, -40)
			level.player.velocity = Vector2.ZERO
		lowest = maxf(lowest, th.global_position.y)
		await tree.physics_frame
		frames += 1
	var b: Rect2 = level.data["bounds"]
	if not _check(level._flags.has("thief_cornered") and lowest < b.end.y, "Ch2: thief must complete his rooftop route without falling (frames=%d, x=%.0f)" % [frames, th.global_position.x]):
		return false
	await _frames(10)
	if not _check(level.obj_index == 1, "Ch2: cornering the thief starts the fight objective"):
		return false
	while not th.health_component.is_dead:
		await _hurt(th, 40)
		await _frames(4)
	await _frames(10)
	if not _check(level.obj_index == 2, "Ch2: defeating the thief starts the recover-device objective"):
		return false
	var case_zone: InteractiveZone = null
	for c in level.world.get_children():
		if c is InteractiveZone and (c as InteractiveZone).zone_id == "tech_case":
			case_zone = c
	await _teleport(level, case_zone.global_position)
	await _frames(200)
	var ok := _check(level.completed and GameState.is_completed(2), "Ch2: collecting the device completes the chapter")
	await _unload(level)
	if ok:
		print("[PASS] Ch2 full thief chase route, thief fight and device recovery (%d chase frames)" % frames)
	return ok


func _test_ch3_and_retry() -> bool:
	# death -> defeat screen -> retry keeps Chapter 3 and the checkpoint
	var level := await _load(3)
	await _teleport(level, Vector2(760, 300 - 16))
	if not _check(GameState.checkpoint_index == 0, "Ch3: touching the first checkpoint records it"):
		return false
	level.player.health_component.is_invulnerable = false
	level.player.health_component.take_damage(999, Vector2.ZERO, "test")
	await _frames(90)
	if not _check(level.failed and level.hud.overlay_panel.visible, "Ch3: death shows the defeat/retry screen"):
		return false
	GameState.retry_level(true)
	if not _check(GameState.current_level == 3 and GameState.checkpoint_index == 0 and GameState.last_route == GameState.CAMPAIGN_LEVEL_SCENE,
			"Ch3: retry must restart Chapter 3 at its checkpoint, not Chapter 1"):
		return false
	await _unload(level)
	level = await _load(3, 0, 0)
	if not _check(absf(level.player.global_position.x - 740.0) < 30.0, "Ch3: respawn happens at the checkpoint"):
		return false
	await _teleport(level, Vector2(2100, 300 - 16))
	await _frames(20)
	var g := level.builder.boss as GoblinBoss
	if not _check(g.engaged and level.obj_index == 1, "Ch3: the Goblin ambush starts in the arena"):
		return false
	while not level._flags.has("scripted_done") and g.hp_ratio() > 0.5:
		await _hurt(g, 25)
		await _frames(3)
	var waited := 0
	while not GameState.is_completed(3) and waited < 600:
		await tree.physics_frame
		waited += 1
	var ok := _check(g._scripted and level.completed and GameState.is_completed(3), "Ch3: reaching 55%% triggers the story defeat and completes the chapter (scripted=%s done=%s completed=%s failed=%s obj=%d hp=%.2f)" % [
		str(g._scripted), str(level._flags.has("scripted_done")), str(level.completed), str(level.failed), level.obj_index, g.hp_ratio()])
	ok = ok and _check(not g.health_component.is_dead, "Ch3: the Goblin survives the ambush (story defeat, not a boss kill)")
	await _unload(level)
	if ok:
		print("[PASS] Ch3 death/retry at checkpoint and scripted Goblin ambush")
	return ok


func _test_ch4() -> bool:
	var level := await _load(4)
	# the lowered duct lets a super jump + W reach the ceiling over the shock corridor
	await _teleport(level, Vector2(1220, 320 - 16))
	_key(KEY_W, true)
	await _frames(2)
	_key(KEY_SPACE, true)
	await _frames(30)
	_key(KEY_SPACE, false)
	var crawled := level.player.current_state == PlayerController.State.CEILING_CRAWLING
	_key(KEY_W, false)
	await _frames(5)
	if not _check(crawled, "Ch4: super jump + W must attach to the ceiling duct (state=%s)" % PlayerController.State.keys()[level.player.current_state]):
		return false
	await _teleport(level, Vector2(660, 320 - 16))
	for t in tree.get_nodes_in_group("generators"):
		for _i in range(3):
			(t as BreakableTarget).receive_hit(10, Vector2.ZERO)
	await _frames(10)
	var all_open := true
	for gate in tree.get_nodes_in_group("gates"):
		all_open = all_open and (gate as SecurityGate).is_open
	if not _check(all_open and level.obj_index == 2, "Ch4: smashing both generators opens both gates"):
		return false
	for e in tree.get_nodes_in_group("guards"):
		await _hurt(e, 999)
	await _frames(6)
	if not _check(level.obj_index == 3, "Ch4: clearing the guards unlocks the cage objective"):
		return false
	for _i in range(5):
		level.builder.cage.receive_hit(10, Vector2.ZERO)
	await _frames(10)
	if not _check(level.follower != null and level.obj_index == 4 and level._escape_time > 0.0, "Ch4: freeing MJ starts the timed escape with MJ following"):
		return false
	await _teleport(level, level.builder.exit_zone.global_position)
	await _frames(200)
	var ok := _check(level.completed and GameState.is_completed(4), "Ch4: reaching the exit with MJ completes the rescue")
	await _unload(level)
	if ok:
		print("[PASS] Ch4 ceiling crawl, generators/gates, guards, cage rescue, follower and escape")
	return ok


func _test_ch5() -> bool:
	var level := await _load(5)
	await _teleport(level, Vector2(900, 300 - 16))
	await _frames(20)
	var g := level.builder.boss as GoblinBoss
	if not _check(g.engaged and g.mode == "final", "Ch5: the final Goblin fight starts"):
		return false
	var drones_before := 0
	for e in tree.get_nodes_in_group("enemies"):
		if e is DroneEnemy:
			drones_before += 1
	while g.phase < 2 and not g.health_component.is_dead:
		await _hurt(g, 20)
		await _frames(3)
	await _frames(5)
	var drones_after := 0
	for e in tree.get_nodes_in_group("enemies"):
		if e is DroneEnemy:
			drones_after += 1
	if not _check(g.phase == 2 and drones_after == drones_before + 2, "Ch5: phase 2 begins below 66% and summons two drones"):
		return false
	await _frames(90)
	while g.phase < 3 and not g.health_component.is_dead:
		await _hurt(g, 20)
		await _frames(3)
	if not _check(g.phase == 3, "Ch5: phase 3 begins below 33%"):
		return false
	await _frames(90)
	while not g.health_component.is_dead:
		await _hurt(g, 25)
		await _frames(3)
	await _frames(220)
	var ok := _check(level.completed and GameState.is_completed(5), "Ch5: defeating the Goblin completes the campaign")
	ok = ok and _check(GameState.story_next == "credits", "Ch5: the finale story leads to the credits")
	await _unload(level)
	if ok:
		print("[PASS] Ch5 three-phase Goblin finale and campaign completion")
	return ok
