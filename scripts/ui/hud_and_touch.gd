class_name HudAndTouchUI
extends CanvasLayer
## Compact HUD + Adaptive Multi-Touch Controls + Pause/Defeat/Victory Overlays.
## Touch buttons trigger the exact same Godot Input Map actions as desktop keyboard keys
## via Input.action_press / Input.action_release and PlayerController.buffer_action_tap,
## supporting both desktop mouse clicks and simultaneous multi-touch on mobile/web.

signal restart_requested()
signal restart_level_requested()
signal menu_requested()
signal touch_button_event(button_name: String, action_name: String, is_pressed: bool)

const ICONS: Dictionary = {
	"BtnLeft": "left", "BtnRight": "right", "BtnUp": "up", "BtnDown": "down", "BtnJump": "jump", "BtnPunch": "punch",
	"BtnKick": "kick", "BtnWeb": "web", "BtnSpecial": "special", "BtnDodge": "dodge",
}

@onready var hp_bar_fill: ColorRect = $RootControl/TopLeftHUD/HPBarBg/HPBarFill
@onready var hp_value_label: Label = $RootControl/TopLeftHUD/HPValueLabel
@onready var state_badge_label: Label = $RootControl/TopLeftHUD/StateBadgeLabel
@onready var cooldown_label: Label = $RootControl/TopLeftHUD/CooldownLabel
@onready var combo_banner_label: Label = $RootControl/TopLeftHUD/ComboBannerLabel

@onready var boss_panel: Control = $RootControl/BossHUD
@onready var boss_name_label: Label = $RootControl/BossHUD/BossNameLabel
@onready var boss_hp_fill: ColorRect = $RootControl/BossHUD/BossHPBg/BossHPFill
@onready var boss_status_label: Label = $RootControl/BossHUD/BossStatusLabel

@onready var overlay_panel: ColorRect = $RootControl/OverlayPanel
@onready var overlay_title: Label = $RootControl/OverlayPanel/VBox/OverlayTitle
@onready var overlay_subtitle: Label = $RootControl/OverlayPanel/VBox/OverlaySubtitle
@onready var resume_button: Button = $RootControl/OverlayPanel/VBox/HBoxButtons/ResumeButton
@onready var retry_button: Button = $RootControl/OverlayPanel/VBox/HBoxButtons/RetryButton

@onready var touch_container: Control = $RootControl/TouchControls
@onready var btn_suit: Button = $RootControl/TopRightBar/BtnSuit
@onready var btn_pause: Button = $RootControl/TopRightBar/BtnPause

# Map of touch Button node -> bound Input Map action name
var _touch_action_bindings: Dictionary = {}
var _active_touch_indices: Dictionary = {} # touch_index -> action_name
var _mouse_held_action: String = ""
var _mouse_held_btn_name: String = ""
var _is_game_over_state: bool = false
var objective_label: Label
var banner_label: Label
var banner_sub: Label
var timer_label: Label
var controls_panel: PanelContainer
var btn_dodge: Button
var btn_restart_level: Button
var btn_menu: Button
var btn_controls: Button
var btn_touch_toggle: Button
var campaign_mode: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	boss_panel.visible = false
	overlay_panel.visible = false

	# Prevent all HUD/overlay buttons from grabbing keyboard focus and consuming Space/Enter/Arrow keys
	resume_button.focus_mode = Control.FOCUS_NONE
	retry_button.focus_mode = Control.FOCUS_NONE
	resume_button.pressed.connect(_on_resume_pressed)
	retry_button.pressed.connect(_on_retry_pressed)

	_bind_touch_button($RootControl/TouchControls/LeftCluster/BtnLeft, "move_left")
	_bind_touch_button($RootControl/TouchControls/LeftCluster/BtnRight, "move_right")
	_bind_touch_button($RootControl/TouchControls/LeftCluster/BtnUp, "climb_up")
	_bind_touch_button($RootControl/TouchControls/LeftCluster/BtnDown, "climb_down")

	_bind_touch_button($RootControl/TouchControls/RightCluster/BtnJump, "jump")
	_bind_touch_button($RootControl/TouchControls/RightCluster/BtnPunch, "attack_punch")
	_bind_touch_button($RootControl/TouchControls/RightCluster/BtnKick, "attack_kick")
	_bind_touch_button($RootControl/TouchControls/RightCluster/BtnWeb, "web_action")
	_bind_touch_button($RootControl/TouchControls/RightCluster/BtnSpecial, "special_action")
	btn_dodge = Button.new()
	btn_dodge.name = "BtnDodge"
	btn_dodge.position = Vector2(4, 68)
	btn_dodge.size = Vector2(48, 30)
	$RootControl/TouchControls/RightCluster.add_child(btn_dodge)
	_bind_touch_button(btn_dodge, "dodge")
	_build_campaign_widgets()
	_apply_visual_style()

	btn_suit.focus_mode = Control.FOCUS_NONE
	btn_suit.pressed.connect(func() -> void:
		_trigger_action_press(btn_suit.name, "suit_toggle")
		var timer := get_tree().create_timer(0.06)
		timer.timeout.connect(func() -> void: _trigger_action_release(btn_suit.name, "suit_toggle"))
	)

	btn_pause.focus_mode = Control.FOCUS_NONE
	btn_pause.pressed.connect(func() -> void:
		touch_button_event.emit("BtnPause", "pause_game", true)
		toggle_pause_menu()
	)

	# Release any accidental GUI focus and ensure the game window has OS keyboard focus
	get_viewport().gui_release_focus()
	var win := get_window()
	if win != null and not DisplayServer.get_name().contains("headless"):
		win.grab_focus()


# ------------------------------------------------------------------ campaign widgets & styling
func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.08, 1))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_campaign_widgets() -> void:
	var root: Control = $RootControl
	objective_label = _label(8, Color(1.0, 0.93, 0.6))
	objective_label.position = Vector2(10, 64)
	objective_label.size = Vector2(300, 12)
	root.add_child(objective_label)
	timer_label = _label(14, Color(1.0, 0.4, 0.35))
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.position = Vector2(-60, 88)
	timer_label.size = Vector2(120, 18)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.visible = false
	root.add_child(timer_label)
	banner_label = _label(22, Color(1.0, 0.95, 0.9))
	banner_label.set_anchors_preset(Control.PRESET_CENTER)
	banner_label.position = Vector2(-240, -60)
	banner_label.size = Vector2(480, 30)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.modulate.a = 0.0
	root.add_child(banner_label)
	banner_sub = _label(10, Color(1.0, 0.75, 0.4))
	banner_sub.set_anchors_preset(Control.PRESET_CENTER)
	banner_sub.position = Vector2(-240, -28)
	banner_sub.size = Vector2(480, 16)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.modulate.a = 0.0
	root.add_child(banner_sub)

	var hbox: HBoxContainer = $RootControl/OverlayPanel/VBox/HBoxButtons
	btn_restart_level = _overlay_button("RESTART CHAPTER", hbox)
	btn_restart_level.pressed.connect(func() -> void:
		touch_button_event.emit("BtnRestartLevel", "restart_level", true)
		restart_level_requested.emit())
	btn_controls = _overlay_button("CONTROLS", hbox)
	btn_controls.pressed.connect(func() -> void: show_controls_guide(false))
	btn_touch_toggle = _overlay_button("TOUCH: ON", hbox)
	btn_touch_toggle.pressed.connect(func() -> void: set_touch_visible(not touch_container.visible))
	var btn_fx := _overlay_button("FX: " + GameState.fx_quality.to_upper(), hbox)
	btn_fx.pressed.connect(func() -> void:
		GameState.fx_quality = "low" if GameState.fx_quality == "high" else "high"
		GameState.save_game()
		btn_fx.text = "FX: " + GameState.fx_quality.to_upper()
		get_tree().call_group("post_fx", "set", "visible", GameState.fx_quality != "low"))
	btn_menu = _overlay_button("MENU", hbox)
	btn_menu.pressed.connect(func() -> void:
		touch_button_event.emit("BtnMenu", "menu", true)
		menu_requested.emit())
	for b in [btn_restart_level, btn_menu]:
		b.visible = false
	_build_controls_panel(root)


func _overlay_button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(80, 26)
	b.add_theme_font_size_override("font_size", 10)
	parent.add_child(b)
	return b


func _build_controls_panel(root: Control) -> void:
	controls_panel = PanelContainer.new()
	controls_panel.set_anchors_preset(Control.PRESET_CENTER)
	controls_panel.position = Vector2(-220, -130)
	controls_panel.size = Vector2(440, 260)
	controls_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.13, 0.96)
	sb.border_color = Color(0.85, 0.2, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	controls_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	controls_panel.add_child(vb)
	var title := _label(14, Color(1, 0.9, 0.5))
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var body := _label(9, Color(0.92, 0.94, 1.0))
	body.text = ("MOVE  A / D  or  Arrows            JUMP  SPACE   (W + SPACE = SUPER JUMP)\n"
		+ "CLIMB  run into walls or hold W    CEILING  jump up into it holding W   (S drops)\n"
		+ "PUNCH  J  (J J J combo, HOLD J = guard-breaking HEAVY)    KICK  H\n"
		+ "BLOCK  hold S     PARRY  block just before a hit lands -> attacker is stunned\n"
		+ "WEB  K  shoots webs  /  in the air near an anchor = WEB SWING (SPACE releases)\n"
		+ "SPECIALS  L = 1 bar   W+L = 2 bars   S+L = 3 bars    (L near a crate throws it)\n"
		+ "DODGE  SHIFT  (SHIFT then J = DASH STRIKE)       SUIT  C       PAUSE  ESC\n\n"
		+ "Touch: hold DOWN to block, hold PUNCH for heavy, UP/DOWN + STAR for big specials.\n"
		+ "Land hits, block and parry to fill the POWER meter. Clean, fast, stylish runs rank S.")
	body.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(body)
	var ok := Button.new()
	ok.text = "GOT IT"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(120, 28)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_close_controls_guide)
	vb.add_child(ok)
	var tap_hint := _label(7, Color(0.7, 0.75, 0.9))
	tap_hint.text = "Tap anywhere on this panel, or press SPACE / ENTER / ESC to continue"
	tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tap_hint)
	# the whole panel dismisses on release so a single tap always works, even on a freshly shown panel
	controls_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and not (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and not (ev as InputEventScreenTouch).pressed):
			_close_controls_guide())
	controls_panel.visible = false
	root.add_child(controls_panel)


var _guide_paused_game: bool = false


func show_controls_guide(pause_game: bool = true) -> void:
	controls_panel.visible = true
	if pause_game and not get_tree().paused:
		_guide_paused_game = true
		get_tree().paused = true


func _close_controls_guide() -> void:
	if not controls_panel.visible:
		return
	controls_panel.visible = false
	if _guide_paused_game:
		_guide_paused_game = false
		get_tree().paused = false
	GameState.seen_controls_guide = true
	GameState.save_game()


func set_touch_visible(on: bool) -> void:
	touch_container.visible = on
	if btn_touch_toggle != null:
		btn_touch_toggle.text = "TOUCH: ON" if on else "TOUCH: OFF"
	if not on:
		release_all_touch_actions()


var fight_hud: FightHUD


## Adds the fighting-game layer (power meter, hit counter, opponent bar) bound to the player.
func attach_fight_hud(p: PlayerController) -> void:
	if fight_hud == null:
		fight_hud = FightHUD.new()
		$RootControl.add_child(fight_hud)
		$RootControl.move_child(fight_hud, 1)
	fight_hud.bind(p)
	state_badge_label.visible = false
	cooldown_label.visible = false


func enable_campaign_mode() -> void:
	campaign_mode = true
	state_badge_label.visible = false
	retry_button.text = "RETRY CHECKPOINT"


func set_objective(text: String) -> void:
	objective_label.text = ("> " + text) if text != "" else ""


func set_timer(seconds: float) -> void:
	timer_label.visible = seconds >= 0.0
	if seconds >= 0.0:
		timer_label.text = "%02d.%d" % [int(seconds), int(fmod(seconds, 1.0) * 10.0)]


func show_banner(title: String, sub: String = "", hold: float = 2.2) -> void:
	banner_label.text = title
	banner_sub.text = sub
	for l: Label in [banner_label, banner_sub]:
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.3)
		tw.tween_interval(hold)
		tw.tween_property(l, "modulate:a", 0.0, 0.5)


func _style_box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	return sb


func _apply_visual_style() -> void:
	for btn_variant in _touch_action_bindings.keys():
		var b := btn_variant as Button
		var icon_name: String = ICONS.get(String(b.name), "")
		if icon_name != "":
			b.icon = load("res://assets/ui/icons/%s.png" % icon_name)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.text = ""
		b.add_theme_stylebox_override("normal", _style_box(Color(0.08, 0.1, 0.2, 0.38), Color(1, 1, 1, 0.35), 10))
		b.add_theme_stylebox_override("hover", _style_box(Color(0.12, 0.15, 0.3, 0.5), Color(1, 1, 1, 0.55), 10))
		b.add_theme_stylebox_override("pressed", _style_box(Color(0.85, 0.2, 0.25, 0.6), Color(1, 1, 1, 0.8), 10))
		b.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.75))
		b.add_theme_color_override("icon_pressed_color", Color(1, 1, 1, 1))
	for b in [btn_suit, btn_pause]:
		b.add_theme_stylebox_override("normal", _style_box(Color(0.08, 0.1, 0.2, 0.55), Color(1, 1, 1, 0.35), 6))
		b.add_theme_stylebox_override("hover", _style_box(Color(0.12, 0.15, 0.3, 0.7), Color(1, 1, 1, 0.55), 6))
		b.add_theme_stylebox_override("pressed", _style_box(Color(0.85, 0.2, 0.25, 0.7), Color(1, 1, 1, 0.8), 6))
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.03, 0.04, 0.1, 0.82)
	overlay_panel.color = Color(0.03, 0.04, 0.1, 0.78)
	hp_bar_fill.color = Color(0.92, 0.22, 0.28)
	cooldown_label.add_theme_font_size_override("font_size", 7)
	cooldown_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95, 0.85))
	objective_label.position = Vector2(10, 46)
	var vbox: VBoxContainer = $RootControl/OverlayPanel/VBox
	vbox.offset_left = -300.0
	vbox.offset_right = 300.0
	($RootControl/OverlayPanel/VBox/HBoxButtons as HBoxContainer).add_theme_constant_override("separation", 6)
	overlay_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for b in [resume_button, retry_button, btn_restart_level, btn_menu, btn_controls, btn_touch_toggle]:
		if b == null:
			continue
		b.custom_minimum_size = Vector2(maxf(66.0, b.custom_minimum_size.x * 0.0), 24)
		b.add_theme_font_size_override("font_size", 9)
		b.add_theme_stylebox_override("normal", _style_box(Color(0.12, 0.14, 0.28, 0.95), Color(0.85, 0.2, 0.25), 5))
		b.add_theme_stylebox_override("hover", _style_box(Color(0.2, 0.22, 0.42, 0.95), Color(1, 0.4, 0.4), 5))
		b.add_theme_stylebox_override("pressed", _style_box(Color(0.85, 0.2, 0.25, 0.95), Color(1, 1, 1), 5))


func _notification(what: int) -> void:
	# Engine focus-loss release skips Input.action_press() state, so a held on-screen button
	# whose release never arrives (alt-tab / window switch mid-press) would keep the action held forever.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all_touch_actions()


func _input(event: InputEvent) -> void:
	if controls_panel != null and controls_panel.visible and not event.is_echo():
		if event.is_action_pressed("pause_game") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or event.is_action_pressed("attack_punch"):
			_close_controls_guide()
			get_viewport().set_input_as_handled()
			return
	# Handle Escape / pause_game directly so GUI controls can never swallow it
	if event.is_action_pressed("pause_game") and not event.is_echo() and not _is_game_over_state:
		toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return

	# Mouse released anywhere (including outside the pressed button) clears the held on-screen action
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _mouse_held_action != "":
			var rel_act := _mouse_held_action
			var rel_btn := _mouse_held_btn_name
			_mouse_held_action = ""
			_mouse_held_btn_name = ""
			_trigger_action_release(rel_btn, rel_act)

	# Multi-touch screen index tracking so holding D-Pad + tapping Jump/Attack works seamlessly on mobile/web.
	# Ignore emulated touch events from desktop mouse clicks (st.device < 0 is emulated mouse).
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.device < 0:
			return
		if st.pressed:
			var hit_btn := _find_touch_button_at(st.position)
			if hit_btn != null:
				var hit_action: String = _touch_action_bindings[hit_btn]
				_active_touch_indices[st.index] = hit_action
				_trigger_action_press(hit_btn.name, hit_action)
		else:
			if _active_touch_indices.has(st.index):
				var rel_action: String = _active_touch_indices[st.index]
				_active_touch_indices.erase(st.index)
				if not _active_touch_indices.values().has(rel_action):
					_trigger_action_release("TouchIdx%d" % st.index, rel_action)

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.device < 0:
			return
		var hit_btn := _find_touch_button_at(sd.position)
		var new_action: String = _touch_action_bindings[hit_btn] if hit_btn != null else ""
		var old_action: String = _active_touch_indices.get(sd.index, "")
		if new_action != old_action:
			if old_action != "":
				_active_touch_indices.erase(sd.index)
				if not _active_touch_indices.values().has(old_action):
					_trigger_action_release("TouchDrag%d" % sd.index, old_action)
			if new_action != "" and hit_btn != null:
				_active_touch_indices[sd.index] = new_action
				_trigger_action_press(hit_btn.name, new_action)


func _bind_touch_button(btn: Button, action_name: String) -> void:
	if btn == null:
		return
	btn.focus_mode = Control.FOCUS_NONE
	_touch_action_bindings[btn] = action_name
	btn.button_down.connect(func() -> void:
		_mouse_held_action = action_name
		_mouse_held_btn_name = btn.name
		_trigger_action_press(btn.name, action_name)
	)
	btn.button_up.connect(func() -> void:
		if _mouse_held_action == action_name:
			_mouse_held_action = ""
			_mouse_held_btn_name = ""
		_trigger_action_release(btn.name, action_name)
	)


func _trigger_action_press(btn_name: String, action_name: String) -> void:
	Input.action_press(action_name)
	for p in get_tree().get_nodes_in_group("player"):
		if p is PlayerController:
			(p as PlayerController).buffer_action_tap(action_name)
	touch_button_event.emit(btn_name, action_name, true)


func _trigger_action_release(btn_name: String, action_name: String) -> void:
	Input.action_release(action_name)
	for p in get_tree().get_nodes_in_group("player"):
		if p is PlayerController:
			(p as PlayerController).buffer_action_release(action_name)
	touch_button_event.emit(btn_name, action_name, false)


func _find_touch_button_at(canvas_pos: Vector2) -> Button:
	## canvas_pos must already be in canvas coordinates: Viewport.push_input() applies the stretch
	## transform before _input(), so transforming again would hit the wrong button when scaled.
	for btn_variant in _touch_action_bindings.keys():
		var btn := btn_variant as Button
		if btn != null and btn.is_visible_in_tree() and btn.get_global_rect().has_point(canvas_pos):
			return btn
	return null


func release_all_touch_actions() -> void:
	for action_name in _touch_action_bindings.values():
		if Input.is_action_pressed(action_name):
			_trigger_action_release("ReleaseAll", action_name)
	_active_touch_indices.clear()
	_mouse_held_action = ""
	_mouse_held_btn_name = ""


func update_player_health(current_hp: int, max_hp: int) -> void:
	var ratio: float = clampf(float(current_hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	hp_bar_fill.size.x = 136.0 * ratio
	hp_value_label.text = "HP %d / %d" % [current_hp, max_hp]


func update_player_state(state_name: String) -> void:
	state_badge_label.text = "STATE: %s" % state_name


func update_ability_cooldowns(super_jump_ready: bool, special_ready: bool, dark_suit: bool) -> void:
	var sj_txt := "READY (W+Space)" if super_jump_ready else "RECHARGING"
	var sp_txt := "READY (L)" if special_ready else "RECHARGING"
	var suit_txt := "BLACK SUIT" if dark_suit else "CLASSIC SUIT"
	cooldown_label.text = "S-JUMP: %s | SPECIAL: %s | %s" % [sj_txt, sp_txt, suit_txt]


func update_combo_banner(combo_count: int, move_label: String) -> void:
	if move_label == "":
		combo_banner_label.text = ""
	elif combo_count > 1:
		combo_banner_label.text = "%dx %s" % [combo_count, move_label]
	else:
		combo_banner_label.text = move_label


func show_boss_hud(boss_title: String, current_hp: int, max_hp: int) -> void:
	boss_panel.visible = true
	boss_name_label.text = boss_title
	update_boss_health(current_hp, max_hp)


func update_boss_health(current_hp: int, max_hp: int) -> void:
	var ratio: float = clampf(float(current_hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	boss_hp_fill.size.x = 220.0 * ratio


func update_boss_status(status_text: String) -> void:
	boss_status_label.text = status_text


func hide_boss_hud() -> void:
	boss_panel.visible = false
	boss_status_label.text = ""


func toggle_pause_menu() -> void:
	if _is_game_over_state:
		return
	var next_paused := not get_tree().paused
	get_tree().paused = next_paused
	overlay_panel.visible = next_paused
	if get_viewport() != null:
		get_viewport().gui_release_focus()
	if next_paused:
		release_all_touch_actions()
		overlay_title.text = "PAUSED"
		_show_campaign_buttons(true)
		overlay_subtitle.text = "A/D: Move | Space: Jump | W+Space: Super Jump | W: Climb/Ceiling\nJ: Punch/Combo | H: Kick | K: Web Shot/Swing | L: Throw/Special | C: Suit"
		resume_button.visible = true


func show_defeat_screen() -> void:
	_is_game_over_state = true
	release_all_touch_actions()
	get_tree().paused = true
	overlay_panel.visible = true
	overlay_title.text = "HERO DEFEATED"
	overlay_subtitle.text = "The city still needs you! Retry from the last checkpoint, or restart the chapter."
	resume_button.visible = false
	retry_button.text = "RETRY CHECKPOINT" if campaign_mode else "RETRY LEVEL"
	_show_campaign_buttons(true)


func show_victory_screen() -> void:
	_is_game_over_state = true
	release_all_touch_actions()
	get_tree().paused = true
	overlay_panel.visible = true
	overlay_title.text = "STAGE CLEAR - BOSS DEFEATED!"
	overlay_subtitle.text = "You mastered traversal, combos, web shots, and defeated the Prototype Enforcer!"
	resume_button.visible = false


func _show_campaign_buttons(on: bool) -> void:
	for b in [btn_restart_level, btn_menu]:
		if b != null:
			b.visible = on and campaign_mode


func hide_overlays_for_reset() -> void:
	_is_game_over_state = false
	release_all_touch_actions()
	get_tree().paused = false
	overlay_panel.visible = false
	if get_viewport() != null:
		get_viewport().gui_release_focus()
	hide_boss_hud()
	combo_banner_label.text = ""


func _on_resume_pressed() -> void:
	touch_button_event.emit("ResumeButton", "resume", true)
	if not _is_game_over_state:
		get_tree().paused = false
		overlay_panel.visible = false
		if get_viewport() != null:
			get_viewport().gui_release_focus()


func _on_retry_pressed() -> void:
	touch_button_event.emit("RetryButton", "retry", true)
	hide_overlays_for_reset()
	restart_requested.emit()
