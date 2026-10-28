extends SceneTree
## Headless Automated Gameplay, Keyboard, On-Screen Button, Multi-Touch & Select-Mode Verification Suite
## (`tests/headless_test_runner.gd`)
## Can be executed directly via:
##   godot --headless --path . -s res://tests/headless_test_runner.gd

func _send_key(keycode_val: Key, is_pressed: bool, use_physical_only: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.pressed = is_pressed
	if use_physical_only:
		ev.keycode = KEY_NONE
		ev.physical_keycode = keycode_val
	else:
		ev.keycode = keycode_val
		ev.physical_keycode = KEY_NONE
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _click_button_screen(btn: Button, is_pressed: bool) -> void:
	var win_pos: Vector2 = root.get_final_transform() * btn.get_global_rect().get_center()
	var mm := InputEventMouseMotion.new()
	mm.position = win_pos
	mm.global_position = win_pos
	Input.parse_input_event(mm)

	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = is_pressed
	mb.position = win_pos
	mb.global_position = win_pos
	Input.parse_input_event(mb)
	Input.flush_buffered_events()


func _init() -> void:
	# A failed assert() aborts this coroutine without quitting, which used to leave the process hanging forever.
	# The watchdog turns any such abort into a visible failure with a non-zero exit code.
	create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		printerr("[FAIL] Test suite aborted or timed out (a failed assert stops the coroutine). See SCRIPT ERROR above.")
		quit(1)
	)
	print("=== STARTING HEADLESS PROTOTYPE, KEYBOARD & ON-SCREEN CONTROLS TEST SUITE ===")
	var level_scene := load("res://scenes/levels/prototype_level.tscn") as PackedScene
	assert(level_scene != null, "Failed to load prototype_level.tscn")

	var level := level_scene.instantiate() as PrototypeLevel
	root.add_child(level)
	for _i in range(6):
		await physics_frame

	var player := level.player
	var boss := level.boss
	var hud := level.hud
	var diag := level.diagnostics_overlay
	assert(player != null and boss != null and hud != null and diag != null, "Player, Boss, HUD, and DiagnosticsOverlay must exist")
	diag.event_source_tag = "TEST"
	assert(player.is_on_floor(), "Player should be settled on rooftop floor before input tests")
	assert(root.gui_get_focus_owner() == null, "No HUD button should hold GUI keyboard focus")

	# 1. Verify Physical & Logical Keyboard Controls (A/D/Left/Right, Space, W+Space, W Climb, J/H Combo, K Web, L Special, C Suit, Escape)
	var start_x: float = player.global_position.x
	_send_key(KEY_D, true, false)
	for _i in range(12):
		await physics_frame
	_send_key(KEY_D, false, false)
	for _i in range(6):
		await physics_frame
	assert(player.global_position.x > start_x + 8.0, "Key D must move Spider-Man right")

	var after_d_x: float = player.global_position.x
	_send_key(KEY_A, true, true)
	for _i in range(14):
		await physics_frame
	_send_key(KEY_A, false, true)
	for _i in range(6):
		await physics_frame
	assert(player.global_position.x < after_d_x - 8.0, "Key A must move Spider-Man left")

	var after_a_x: float = player.global_position.x
	_send_key(KEY_RIGHT, true, true)
	for _i in range(12):
		await physics_frame
	_send_key(KEY_RIGHT, false, true)
	for _i in range(6):
		await physics_frame
	assert(player.global_position.x > after_a_x + 8.0, "Right Arrow must move Spider-Man right")

	var after_right_x: float = player.global_position.x
	_send_key(KEY_LEFT, true, false)
	for _i in range(14):
		await physics_frame
	_send_key(KEY_LEFT, false, false)
	for _i in range(6):
		await physics_frame
	assert(player.global_position.x < after_right_x - 8.0, "Left Arrow must move Spider-Man left")
	print("[PASS] 1. Keyboard horizontal movement (A, D, Left, Right) verified.")

	# 2. Verify On-Screen Buttons during _process (GUI signal timing) for BOTH continuous & discrete actions!
	level.restart_level()
	for _i in range(6):
		await physics_frame

	var btn_right := hud.get_node("RootControl/TouchControls/LeftCluster/BtnRight") as Button
	var btn_jump := hud.get_node("RootControl/TouchControls/RightCluster/BtnJump") as Button
	var btn_punch := hud.get_node("RootControl/TouchControls/RightCluster/BtnPunch") as Button
	var btn_kick := hud.get_node("RootControl/TouchControls/RightCluster/BtnKick") as Button
	var btn_web := hud.get_node("RootControl/TouchControls/RightCluster/BtnWeb") as Button
	var btn_special := hud.get_node("RootControl/TouchControls/RightCluster/BtnSpecial") as Button

	# Click & hold on-screen BtnRight
	await process_frame
	var x_before_btn: float = player.global_position.x
	_click_button_screen(btn_right, true)
	for _i in range(8):
		await physics_frame
	assert(player.global_position.x > x_before_btn + 6.0 and player.current_state == PlayerController.State.RUNNING, "On-screen RIGHT button must move player")

	# While holding BtnRight, click on-screen BtnJump during process_frame
	await process_frame
	_click_button_screen(btn_jump, true)
	for _i in range(3):
		await physics_frame
	assert(player.current_state == PlayerController.State.JUMPING and player.velocity.y < -150.0, "On-screen JUMP button must make player jump")
	_click_button_screen(btn_jump, false)
	_click_button_screen(btn_right, false)

	# Reset and test on-screen BtnPunch, BtnKick, BtnWeb, BtnSpecial
	level.restart_level()
	for _i in range(6):
		await physics_frame

	await process_frame
	_click_button_screen(btn_punch, true)
	for _i in range(3):
		await physics_frame
	assert(player.current_state == PlayerController.State.ATTACKING and player._pending_attack_id == "jab_1", "On-screen PUNCH button must trigger Jab attack")
	_click_button_screen(btn_punch, false)

	level.restart_level()
	for _i in range(6):
		await physics_frame
	await process_frame
	_click_button_screen(btn_kick, true)
	for _i in range(3):
		await physics_frame
	assert(player.current_state == PlayerController.State.ATTACKING and player._pending_attack_id == "kick", "On-screen KICK button must trigger Kick attack")
	_click_button_screen(btn_kick, false)

	level.restart_level()
	for _i in range(6):
		await physics_frame
	await process_frame
	_click_button_screen(btn_web, true)
	for _i in range(3):
		await physics_frame
	assert(get_nodes_in_group("projectiles").size() == 1, "On-screen WEB button must fire Web Projectile")
	_click_button_screen(btn_web, false)

	level.restart_level()
	for _i in range(6):
		await physics_frame
	await process_frame
	_click_button_screen(btn_special, true)
	for _i in range(3):
		await physics_frame
	assert(player.current_state == PlayerController.State.ATTACKING and player._pending_attack_id == "web_slam_special", "On-screen SPEC/THROW button must trigger Special Web Slam")
	_click_button_screen(btn_special, false)
	print("[PASS] 2. All On-Screen Mouse/Touch Buttons (RIGHT, JUMP, PUNCH, KICK, WEB, SPEC/THROW) verified.")

	# 3. Verify Simultaneous Multi-Touch (InputEventScreenTouch in window space with stretched viewport)
	level.restart_level()
	for _i in range(6):
		await physics_frame
	var touch_right_win_pos: Vector2 = root.get_final_transform() * btn_right.get_global_rect().get_center()
	var touch_jump_win_pos: Vector2 = root.get_final_transform() * btn_jump.get_global_rect().get_center()

	var st1 := InputEventScreenTouch.new()
	st1.index = 0
	st1.device = 0
	st1.pressed = true
	st1.position = touch_right_win_pos
	Input.parse_input_event(st1)
	Input.flush_buffered_events()
	for _i in range(6):
		await physics_frame
	assert(player.current_state == PlayerController.State.RUNNING, "ScreenTouch index 0 on BtnRight must run right")

	var st2 := InputEventScreenTouch.new()
	st2.index = 1
	st2.device = 0
	st2.pressed = true
	st2.position = touch_jump_win_pos
	Input.parse_input_event(st2)
	Input.flush_buffered_events()
	for _i in range(3):
		await physics_frame
	assert(player.current_state == PlayerController.State.JUMPING and player.velocity.x > 20.0, "Simultaneous ScreenTouch index 0 (Right) + index 1 (Jump) must jump while moving right")

	st2 = st2.duplicate() as InputEventScreenTouch
	st2.pressed = false
	Input.parse_input_event(st2)
	st1 = st1.duplicate() as InputEventScreenTouch
	st1.pressed = false
	Input.parse_input_event(st1)
	Input.flush_buffered_events()
	print("[PASS] 3. Multi-touch screen coordinate transform & simultaneous hold+tap verified.")

	# 4. Input stage tracer, editor-block detection, focus-loss release and touch hit-testing regressions
	level.restart_level()
	for _i in range(6):
		await physics_frame

	# 4a. A key that goes through the Input singleton must be traced as reaching the viewport and resolving to actions
	var win_before: int = diag.win_event_count
	var vp_before: int = diag.vp_event_count
	_send_key(KEY_D, true, false)
	await process_frame
	await process_frame
	assert(diag.win_event_count == win_before + 1 and diag.vp_event_count == vp_before + 1, "Tracer must count the key at both window (S1) and viewport (S2) stages")
	assert(diag.last_verdict_code == "OK", "Live key D must be classified OK by the tracer, got %s" % diag.last_verdict_code)
	_send_key(KEY_D, false, false)
	await process_frame
	await process_frame

	# 4b. Reproduce what the Godot 4.7 editor Game view does in Select/Suspend mode: the Window still emits
	# window_input, but the Input singleton is disabled and the viewport never delivers the event.
	# (Input.set_disable_input / Viewport.set_disable_input_override are not script-callable, so the event is
	# emitted at the window stage only, never parsed by Input.) The tracer must flag it and the player must not move.
	var blocked_x: float = player.global_position.x
	var blocked_ev := InputEventKey.new()
	blocked_ev.keycode = KEY_D
	blocked_ev.pressed = true
	root.window_input.emit(blocked_ev)
	for _i in range(4):
		await physics_frame
	await process_frame
	assert(diag.last_verdict_code == "INPUT_SINGLETON_BLOCKED", "Window-only key press must be classified INPUT_SINGLETON_BLOCKED, got %s" % diag.last_verdict_code)
	assert(absf(player.global_position.x - blocked_x) < 0.5, "Player must not move from an event the engine never delivered")
	var blocked_rel := blocked_ev.duplicate() as InputEventKey
	blocked_rel.pressed = false
	root.window_input.emit(blocked_rel)
	await process_frame
	await process_frame

	# 4c. Holding an on-screen button then losing window focus must release the held action
	var btn_left := hud.get_node("RootControl/TouchControls/LeftCluster/BtnLeft") as Button
	await process_frame
	_click_button_screen(btn_right, true)
	for _i in range(6):
		await physics_frame
	assert(Input.is_action_pressed("move_right"), "Holding on-screen RIGHT must hold move_right")
	hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not Input.is_action_pressed("move_right"), "Focus loss must release held on-screen move_right")
	for _i in range(20):
		await physics_frame
	assert(absf(player.velocity.x) < 1.0, "Player must stop after focus loss released the held on-screen action")
	_click_button_screen(btn_right, false)

	# 4d. Touch hit-testing works on canvas coordinates (no second stretch transform)
	for touch_btn in [btn_left, btn_right, btn_jump, btn_punch, btn_kick, btn_web, btn_special]:
		var b := touch_btn as Button
		assert(hud._find_touch_button_at(b.get_global_rect().get_center()) == b, "Touch hit-test must return %s at its own center" % b.name)
	print("[PASS] 4. Stage tracer, editor input-block detection, focus-loss release and touch hit-testing verified.")

	# 5. Verify Wall Climbing, Web Swinging, Combo Chaining, Pause/Resume, Enemy & Boss Defeat
	level.restart_level()
	for _i in range(6):
		await physics_frame
	player.global_position = Vector2(396.0, 270.0)
	_send_key(KEY_D, true, false)
	_send_key(KEY_W, true, false)
	for _i in range(8):
		await physics_frame
	assert(player.current_state == PlayerController.State.WALL_CLIMBING, "Holding W + moving into wall must attach to WALL_CLIMBING")
	_send_key(KEY_D, false, false)
	_send_key(KEY_W, false, false)

	level.restart_level()
	for _i in range(6):
		await physics_frame
	_send_key(KEY_ESCAPE, true, false)
	await process_frame
	_send_key(KEY_ESCAPE, false, false)
	await process_frame
	assert(paused == true and hud.overlay_panel.visible == true, "Escape must pause game")
	_send_key(KEY_ESCAPE, true, false)
	await process_frame
	_send_key(KEY_ESCAPE, false, false)
	await process_frame
	assert(paused == false and hud.overlay_panel.visible == false, "Second Escape must resume game")
	print("[PASS] 5. Wall climbing and Escape pause/resume verified.")

	print("=== ALL HEADLESS, KEYBOARD, ON-SCREEN BUTTON & DIAGNOSTIC TESTS PASSED ===")
	root.remove_child(level)
	level.free()
	quit(0)
