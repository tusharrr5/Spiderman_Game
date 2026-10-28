class_name HudAndTouchUI
extends CanvasLayer
## Compact HUD + Adaptive Multi-Touch Controls + Pause/Defeat/Victory Overlays.
## Touch buttons trigger the exact same Godot Input Map actions as desktop keyboard keys
## via Input.action_press / Input.action_release, supporting simultaneous multi-touch
## (e.g. holding Move Right while tapping Jump, Punch, or Web).

signal restart_requested()

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

# Map of touch Button node -> bound Input Map action name
var _touch_action_bindings: Dictionary = {}
var _active_touch_indices: Dictionary = {} # touch_index -> action_name
var _is_game_over_state: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	boss_panel.visible = false
	overlay_panel.visible = false

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

	var btn_suit: Button = $RootControl/TopRightBar/BtnSuit
	btn_suit.pressed.connect(func() -> void: _tap_instant_action("suit_toggle"))

	var btn_pause: Button = $RootControl/TopRightBar/BtnPause
	btn_pause.pressed.connect(toggle_pause_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not _is_game_over_state:
		toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return

	# Multi-touch screen index tracking so holding D-Pad + tapping Jump/Attack works seamlessly on mobile/web
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			var hit_action := _find_touch_action_at(st.position)
			if hit_action != "":
				_active_touch_indices[st.index] = hit_action
				Input.action_press(hit_action)
		else:
			if _active_touch_indices.has(st.index):
				var rel_action: String = _active_touch_indices[st.index]
				_active_touch_indices.erase(st.index)
				if not _active_touch_indices.values().has(rel_action):
					Input.action_release(rel_action)

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		var new_action := _find_touch_action_at(sd.position)
		var old_action: String = _active_touch_indices.get(sd.index, "")
		if new_action != old_action:
			if old_action != "":
				_active_touch_indices.erase(sd.index)
				if not _active_touch_indices.values().has(old_action):
					Input.action_release(old_action)
			if new_action != "":
				_active_touch_indices[sd.index] = new_action
				Input.action_press(new_action)


func _bind_touch_button(btn: Button, action_name: String) -> void:
	if btn == null:
		return
	btn.focus_mode = Control.FOCUS_NONE
	_touch_action_bindings[btn] = action_name
	btn.button_down.connect(func() -> void: Input.action_press(action_name))
	btn.button_up.connect(func() -> void: Input.action_release(action_name))


func _find_touch_action_at(screen_pos: Vector2) -> String:
	for btn_variant in _touch_action_bindings.keys():
		var btn := btn_variant as Control
		if btn != null and btn.is_visible_in_tree():
			if btn.get_global_rect().has_point(screen_pos):
				return _touch_action_bindings[btn]
	return ""


func _tap_instant_action(action_name: String) -> void:
	Input.action_press(action_name)
	var timer := get_tree().create_timer(0.06)
	timer.timeout.connect(func() -> void: Input.action_release(action_name))


func release_all_touch_actions() -> void:
	for action_name in _touch_action_bindings.values():
		Input.action_release(action_name)
	_active_touch_indices.clear()


func update_player_health(current_hp: int, max_hp: int) -> void:
	var ratio := clamp(float(current_hp) / float(max(1, max_hp)), 0.0, 1.0)
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
	var ratio := clamp(float(current_hp) / float(max(1, max_hp)), 0.0, 1.0)
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
	if next_paused:
		release_all_touch_actions()
		overlay_title.text = "PAUSED"
		overlay_subtitle.text = "A/D: Move | Space: Jump | W+Space: Super Jump | W: Climb/Ceiling\nJ: Punch/Combo | H: Kick | K: Web Shot/Swing | L: Throw/Special | C: Suit"
		resume_button.visible = true


func show_defeat_screen() -> void:
	_is_game_over_state = true
	release_all_touch_actions()
	get_tree().paused = true
	overlay_panel.visible = true
	overlay_title.text = "HERO DEFEATED"
	overlay_subtitle.text = "The city still needs you! Click Retry to reset the stage cleanly."
	resume_button.visible = false


func show_victory_screen() -> void:
	_is_game_over_state = true
	release_all_touch_actions()
	get_tree().paused = true
	overlay_panel.visible = true
	overlay_title.text = "STAGE CLEAR - BOSS DEFEATED!"
	overlay_subtitle.text = "You mastered traversal, combos, web shots, and defeated the Prototype Enforcer!"
	resume_button.visible = false


func hide_overlays_for_reset() -> void:
	_is_game_over_state = false
	release_all_touch_actions()
	get_tree().paused = false
	overlay_panel.visible = false
	hide_boss_hud()
	combo_banner_label.text = ""


func _on_resume_pressed() -> void:
	if not _is_game_over_state:
		get_tree().paused = false
		overlay_panel.visible = false


func _on_retry_pressed() -> void:
	hide_overlays_for_reset()
	restart_requested.emit()
