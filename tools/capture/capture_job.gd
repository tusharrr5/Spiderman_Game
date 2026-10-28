extends RefCounted

var tree: SceneTree
## Renders real in-game screenshots (menus, every chapter, bosses) for visual QA and the README.
## Job run by tools/capture/capture_scenes.gd (needs a rendering window, not --headless).

var out_dir: String = "user://captures"


func run(p_tree: SceneTree, p_out: String) -> void:
	tree = p_tree
	out_dir = p_out
	DirAccess.make_dir_recursive_absolute(out_dir)
	Fx.hitstop_enabled = false
	GameState.save_path = "user://capture_save.cfg"
	GameState.routing_enabled = false
	GameState.seen_controls_guide = true
	GameState.highest_unlocked = 5
	GameState.completed = {1: true, 2: true}
	GameState.best_times = {1: 312.0, 2: 401.0}

	await _menu("res://scenes/menus/title_screen.tscn", "00_title")
	await _menu("res://scenes/menus/level_select.tscn", "01_level_select")
	GameState.pending_story = "ch4_intro"
	await _menu("res://scenes/menus/story_scene.tscn", "02_story", 50)
	GameState.tokens = 1450
	GameState.arena_best = {"gauntlet": 2, "survival": 11, "survival_score": 8420}
	GameState.chapter_rank = {1: "S", 2: "A"}
	GameState.chapter_stars = {1: 3, 2: 3}
	await _menu("res://scenes/menus/arena_hub.tscn", "03_arena_hub")
	await _menu("res://scenes/menus/shop.tscn", "04_shop")
	await _arena_shot()
	await _versus_shots()

	var shots := [
		[1, Vector2(320, 284), "", "10_ch1_start"],
		[1, Vector2(1300, 154), "", "11_ch1_highroof"],
		[1, Vector2(2780, 284), "boss", "12_ch1_brick"],
		[2, Vector2(900, 264), "", "20_ch2_chase"],
		[2, Vector2(2400, 304), "", "21_ch2_construction"],
		[3, Vector2(960, 284), "", "30_ch3_yard"],
		[3, Vector2(2300, 284), "boss", "31_ch3_goblin"],
		[4, Vector2(1300, 304), "", "40_ch4_facility"],
		[4, Vector2(3250, 304), "", "41_ch4_cage"],
		[5, Vector2(1200, 284), "boss", "50_ch5_finale"],
	]
	for s in shots:
		await _level_shot(s[0], s[1], s[2], s[3])
	print("captures written to ", ProjectSettings.globalize_path(out_dir))


func _versus_shots() -> void:
	GameState.versus_stats = {"wins": 14, "losses": 5, "streak": 4, "best_streak": 7}
	GameState.char_wins = {"miles": 6, "gwen": 4, "noir": 3}
	GameState.versus_config = {"mode": "3v3", "difficulty": "difficult"}
	var setup: Control = load("res://scenes/menus/versus_setup.tscn").instantiate()
	tree.root.add_child(setup)
	for _i in range(15):
		await tree.process_frame
	await _save("70_versus_setup")
	(setup.find_child("Next", true, false) as Button).pressed.emit()
	for k in ["miles", "gwen", "noir"]:
		(setup.find_child("Pick_" + k, true, false) as Button).pressed.emit()
	(setup.find_child("Pick_peni", true, false) as Button).grab_focus()
	for _i in range(15):
		await tree.process_frame
	await _save("71_fighter_select")
	setup.queue_free()
	await tree.process_frame
	var v := VersusLevel.new()
	v.config = {"mode": "cpu", "difficulty": "difficult", "stage": "storm_finale", "team1": ["miles", "gwen", "peni"],
		"team2": ["noir", "2099", "punk"], "cpu_vs_cpu": true, "ai_seed": 4}
	tree.root.add_child(v)
	for _i in range(330):
		await tree.physics_frame
	await _save("72_versus_fight")
	v.queue_free()
	await tree.process_frame
	v = VersusLevel.new()
	v.config = {"mode": "1v1", "difficulty": "more_difficult", "stage": "rooftop_sunset", "team1": ["ham"], "team2": ["iron"],
		"cpu_vs_cpu": true, "ai_seed": 8}
	tree.root.add_child(v)
	for _i in range(260):
		await tree.physics_frame
	await _save("73_versus_1v1")
	v.queue_free()
	await tree.process_frame


func _arena_shot() -> void:
	var a := ArenaLevel.new()
	a.mode = "gauntlet"
	a.tier = 3
	tree.root.add_child(a)
	a.hud.set_touch_visible(false)
	for _i in range(150):
		await tree.physics_frame
	a.player.set_meter(250.0)
	a.player.sprite.play("heavy", true)
	for _i in range(8):
		await tree.process_frame
	await _save("60_arena_fight")
	a.queue_free()
	await tree.process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))


func _menu(path: String, name: String, frames: int = 20) -> void:
	var scene: Node = load(path).instantiate()
	tree.root.add_child(scene)
	for _i in range(frames):
		await tree.process_frame
	await _save(name)
	scene.queue_free()
	await tree.process_frame


func _level_shot(n: int, pos: Vector2, mode: String, name: String) -> void:
	GameState.current_level = n
	GameState.checkpoint_index = -1
	var level := CampaignLevel.new()
	level.level_number = n
	tree.root.add_child(level)
	for _i in range(10):
		await tree.physics_frame
	level.player.global_position = pos
	level.player.velocity = Vector2.ZERO
	(level.player.get_node("Camera2D") as Camera2D).reset_smoothing()
	for _i in range(40):
		await tree.physics_frame
	if mode == "boss" and level.builder.boss != null:
		for _i in range(70):
			await tree.physics_frame
	# show off an attack pose in some shots
	level.player.sprite.play("kick" if n % 2 == 0 else "jab", true)
	for _i in range(4):
		await tree.process_frame
	await _save(name)
	level.queue_free()
	for p in tree.get_nodes_in_group("projectiles"):
		p.queue_free()
	await tree.process_frame
	await tree.process_frame
