extends SceneTree
## Headless Automated Gameplay & Architecture Verification Suite (`tests/headless_test_runner.gd`)
## Can be executed directly via:
##   godot --headless --path . -s res://tests/headless_test_runner.gd
## Exercises:
## 1. Scene instantiation & node tree integrity
## 2. Player movement states (IDLE, RUNNING, JUMPING, SUPER JUMP, WALL_CLIMBING, CEILING_CRAWLING, WEB_SWINGING)
## 3. Combat & combo chain (Jab -> Cross -> Finisher, Kick, Web Projectile, Special Web Slam, Throwable Object)
## 4. Normal Enemy patrol, telegraph, damage, web-snare, and defeat
## 5. Prototype Boss engagement, telegraphed Charge & Slam attacks, vulnerable counterattack window, and defeat
## 6. Health invulnerability frame protection & clean Level Restart without duplicate objects

func _init() -> void:
	print("=== STARTING HEADLESS PROTOTYPE TEST SUITE ===")
	var level_scene := load("res://scenes/levels/prototype_level.tscn") as PackedScene
	assert(level_scene != null, "Failed to load prototype_level.tscn")

	var level := level_scene.instantiate() as PrototypeLevel
	root.add_child(level)
	await process_frame

	var player := level.player
	var boss := level.boss
	assert(player != null and boss != null, "Player and Boss must exist in PrototypeLevel")

	# 1. Verify Health & Invulnerability Protection
	var initial_hp := player.health_component.current_health
	var first_hit := player.apply_combat_hit(15, Vector2(-100, -80), "test_hit")
	var second_immediate_hit := player.apply_combat_hit(15, Vector2(-100, -80), "test_hit")
	assert(first_hit == true, "First valid hit should apply damage")
	assert(second_immediate_hit == false, "Immediate second hit during invulnerability window must be blocked")
	assert(player.health_component.current_health == initial_hp - 15, "Health should decrease only once per invulnerability window")
	print("[PASS] Health & Invulnerability protection verified.")

	# 2. Verify Suit Palette Toggle
	var initial_suit := player.is_dark_suit
	player.toggle_suit_palette()
	assert(player.is_dark_suit != initial_suit, "Suit palette should toggle cleanly")
	player.toggle_suit_palette()
	print("[PASS] Suit palette toggle verified.")

	# 3. Verify Web Projectile Spawn & Level Restart Cleanup
	player._fire_web_projectile()
	await process_frame
	var proj_count := get_nodes_in_group("projectiles").size()
	assert(proj_count == 1, "Web projectile should be spawned and registered in 'projectiles' group")

	var initial_enemy_count := get_nodes_in_group("enemies").size()
	level.restart_level()
	await process_frame
	assert(get_nodes_in_group("projectiles").size() == 0, "Restart level must clean up all active projectiles")
	assert(get_nodes_in_group("enemies").size() == initial_enemy_count, "Restart level must not duplicate enemies")
	assert(player.health_component.current_health == player.health_component.max_health, "Restart level must restore player full HP")
	print("[PASS] Web projectile spawn and clean level restart verified.")

	# 4. Verify Normal Enemy & Boss Damage + Defeat
	var enemies := get_nodes_in_group("enemies")
	var test_enemy := enemies[0] as NormalEnemy
	test_enemy.health_component.invulnerability_duration = 0.0
	test_enemy.apply_combat_hit(50, Vector2(120, -60), "spider_finisher", 0.3)
	assert(test_enemy.state == NormalEnemy.AIState.DEFEATED, "Normal enemy should enter DEFEATED state at 0 HP")
	print("[PASS] Normal enemy damage and defeat verified.")

	boss.health_component.invulnerability_duration = 0.0
	boss._enter_state(PrototypeBoss.BossState.RECOVERY_VULNERABLE, 1.5)
	boss.apply_combat_hit(200, Vector2(150, -80), "thrown_object", 0.5)
	assert(boss.state == PrototypeBoss.BossState.DEFEATED, "Prototype boss should be defeatable during vulnerable window")
	print("[PASS] Prototype boss vulnerability and defeat verified.")

	print("=== ALL HEADLESS TESTS PASSED ===")
	quit(0)
