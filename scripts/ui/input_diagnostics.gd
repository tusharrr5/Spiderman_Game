class_name InputDiagnosticsOverlay
extends CanvasLayer
## Independent Runtime Input Stage Tracer (Layer 20).
## Built purely in code with no dependence on HudAndTouchUI so it remains visible and functional
## even if the ordinary HUD is hidden or broken. It never consumes input (all Controls IGNORE the mouse,
## and no event is ever marked handled).
## Toggle visibility at any time with F3 or Backquote (`), or set `show_diagnostics = false`.
##
## Every key / mouse event is traced through these stages and appended to user://input_diag.log:
##   S1 WIN   Root Window received the OS event (Window.window_input signal, fires even if the viewport is blocked)
##   S2 VP    Root Viewport delivered it to Node._input (blocked by Godot editor Game view Select/Suspend mode)
##   S3 MAP   Input Map actions the event resolves to (InputMap.event_is_action)
##   S3b SING Input singleton reports those actions as pressed (false => Input.set_disable_input(true) by the editor)
##   S4 BUF   Player one-shot buffers / held movement axis seen on the next physics tick
##   S5/S6    Player state + velocity after the tick, and every state transition

## One log per run mode so an editor-embedded run and a standalone run never overwrite each other
const LOG_PATH_FORMAT: String = "user://input_diag_%s.log"
const TRACKED_ACTIONS: Array[String] = ["move_left", "move_right", "climb_up", "climb_down", "jump", "attack_punch", "attack_kick", "web_action", "special_action", "suit_toggle", "pause_game"]

@export var show_diagnostics: bool = true
## Prefix written on every log line. The headless test runner sets this to "TEST" so synthetic
## Input.parse_input_event() traffic is never confused with real OS keyboard / mouse events.
var event_source_tag: String = "OS"

var _panel: ColorRect
var _label: Label
var _log_file: FileAccess = null
var _was_paused: bool = false

# Stage counters (cumulative)
var win_event_count: int = 0
var vp_event_count: int = 0

# Last traced event (finalized one frame after it arrives)
var _pending_event: InputEvent = null
var _pending_win_frame: int = -1
var _pending_vp_delivered: bool = false
var _pending_actions: Array[String] = []
var _pending_singleton_ok: bool = true

var last_key_event_str: String = "None"
var last_mouse_event_str: String = "None"
var last_touch_event_str: String = "None"
var last_onscreen_btn_str: String = "None"
var last_invoked_action_str: String = "None"
var last_trace_verdict: String = "No input yet"
var last_state_change_str: String = "None"
## Classification of the most recent finalized key/mouse press:
## "OK", "VIEWPORT_BLOCKED", "INPUT_SINGLETON_BLOCKED", "UNMAPPED"
var last_verdict_code: String = ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = ColorRect.new()
	_panel.name = "DiagPanel"
	_panel.position = Vector2(140.0, 80.0)
	_panel.size = Vector2(360.0, 150.0)
	_panel.color = Color(0.02, 0.04, 0.09, 0.82)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = show_diagnostics
	add_child(_panel)

	_label = Label.new()
	_label.name = "DiagLabel"
	_label.position = Vector2(5.0, 3.0)
	_label.size = Vector2(350.0, 144.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.75, 1.0))
	_panel.add_child(_label)

	var root_win := get_tree().root
	if root_win != null and not root_win.window_input.is_connected(_on_root_window_input):
		root_win.window_input.connect(_on_root_window_input)

	var run_mode := "standalone"
	if Engine.is_embedded_in_editor():
		run_mode = "editor_embedded"
	elif DisplayServer.get_name() == "headless":
		run_mode = "headless"
	var log_path := LOG_PATH_FORMAT % run_mode
	_log_file = FileAccess.open(log_path, FileAccess.WRITE)
	_log("SESSION START mode=%s display=%s pid=%d os=%s log=%s" % [
		run_mode, DisplayServer.get_name(), OS.get_process_id(), OS.get_name(), ProjectSettings.globalize_path(log_path)
	])
	print("[InputDiag] Logging input stages to ", ProjectSettings.globalize_path(log_path))
	_log("VIEWPORT window_size=%s canvas_size=%s final_transform=%s" % [
		str(get_window().size), str(get_viewport().get_visible_rect().size), str(get_viewport().get_final_transform())
	])

	# Connect to the player (sibling under the level) once the tree is ready
	_connect_player.call_deferred()


func _connect_player() -> void:
	var player := _get_player()
	if player != null and not player.state_changed.is_connected(_on_player_state_changed):
		player.state_changed.connect(_on_player_state_changed)


func _get_player() -> PlayerController:
	var p_nodes := get_tree().get_nodes_in_group("player")
	if p_nodes.size() > 0 and p_nodes[0] is PlayerController:
		return p_nodes[0] as PlayerController
	return null


func _log(line: String) -> void:
	if _log_file == null:
		return
	_log_file.store_line("[%s f%d] %s" % [event_source_tag, Engine.get_process_frames(), line])
	_log_file.flush()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_log("APP FOCUS IN")
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_log("APP FOCUS OUT")
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_log("WINDOW FOCUS IN")
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_log("WINDOW FOCUS OUT")
		NOTIFICATION_PREDELETE:
			if _log_file != null:
				_log_file.close()
				_log_file = null


func record_onscreen_button(btn_name: String, action_name: String, is_pressed: bool) -> void:
	var state_word: String = "DOWN" if is_pressed else "UP"
	last_onscreen_btn_str = "%s (%s)" % [btn_name, state_word]
	last_invoked_action_str = "%s -> %s (Input.is_action_pressed=%s)" % [
		action_name,
		state_word,
		str(Input.is_action_pressed(action_name))
	]
	_log("ONSCREEN %s %s action=%s Input.is_action_pressed=%s" % [btn_name, state_word, action_name, str(Input.is_action_pressed(action_name))])


func _on_player_state_changed(new_state_name: String) -> void:
	var player := _get_player()
	var vel: Vector2 = player.velocity if player != null else Vector2.ZERO
	last_state_change_str = "%s @f%d vel(%.0f,%.0f)" % [new_state_name, Engine.get_process_frames(), vel.x, vel.y]
	_log("S5 PLAYER STATE -> %s vel=(%.0f,%.0f)" % [new_state_name, vel.x, vel.y])


# ------------------------------------------------------------------------------
# Stage 1: OS event reached the root Window (fires even when the viewport is blocked)
# ------------------------------------------------------------------------------
func _on_root_window_input(event: InputEvent) -> void:
	if not _is_traceable(event):
		return
	_finalize_pending()
	win_event_count += 1
	_describe_raw_event(event, "win")

	if _is_toggle_key(event):
		# Toggled from the window stage so F3 still works while the viewport is blocked
		show_diagnostics = not show_diagnostics
		if _panel != null:
			_panel.visible = show_diagnostics
		return

	var is_press := _is_press(event)
	_pending_actions = _resolve_actions(event)
	# Input state is updated before window dispatch, so a mapped press must already be visible here.
	_pending_singleton_ok = true
	if is_press:
		for act in _pending_actions:
			if not Input.is_action_pressed(act):
				_pending_singleton_ok = false
	_pending_event = event
	_pending_win_frame = Engine.get_process_frames()
	_pending_vp_delivered = false

	_log("S1 WIN %s | S3 MAP %s | S3b Input.is_action_pressed=%s" % [
		_event_short(event), _actions_str(_pending_actions), "n/a" if not is_press or _pending_actions.is_empty() else str(_pending_singleton_ok)
	])


# ------------------------------------------------------------------------------
# Stage 2: Root viewport delivered the event to the scene tree
# ------------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not _is_traceable(event):
		return
	vp_event_count += 1
	if _pending_event != null and _same_event(_pending_event, event):
		_pending_vp_delivered = true
	if event is InputEventMouseButton:
		# Canvas-space position + the Control under it shows whether a click actually landed on a HUD button
		var hovered := get_viewport().gui_get_hovered_control()
		_log("S2 VP mouse canvas=(%.0f,%.0f) hovered=%s" % [
			(event as InputEventMouseButton).position.x, (event as InputEventMouseButton).position.y,
			str(hovered.get_path()) if hovered != null else "None"
		])


func _is_traceable(event: InputEvent) -> bool:
	if event is InputEventKey:
		return not (event as InputEventKey).echo
	return event is InputEventMouseButton or event is InputEventScreenTouch


func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _is_toggle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var ke := event as InputEventKey
	return ke.pressed and (ke.keycode == KEY_F3 or ke.physical_keycode == KEY_F3 or ke.keycode == KEY_QUOTELEFT)


func _same_event(a: InputEvent, b: InputEvent) -> bool:
	# Mouse/touch events are copied (coordinate transform) on their way into the viewport, keys are not.
	if a == b:
		return true
	if a.get_class() != b.get_class():
		return false
	if a is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index and _is_press(a) == _is_press(b)
	if a is InputEventScreenTouch:
		return (a as InputEventScreenTouch).index == (b as InputEventScreenTouch).index and _is_press(a) == _is_press(b)
	return false


func _resolve_actions(event: InputEvent) -> Array[String]:
	var acts: Array[String] = []
	for act in TRACKED_ACTIONS:
		if InputMap.event_is_action(event, act):
			acts.append(act)
	return acts


func _actions_str(acts: Array[String]) -> String:
	return "[" + ", ".join(acts) + "]" if acts.size() > 0 else "[none]"


func _event_short(event: InputEvent) -> String:
	if event is InputEventKey:
		var ke := event as InputEventKey
		var code: Key = ke.keycode if ke.keycode != KEY_NONE else ke.physical_keycode
		return "key %s %s (kc=%d pk=%d)" % [OS.get_keycode_string(code), "PRESS" if ke.pressed else "REL", ke.keycode, ke.physical_keycode]
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return "mouse btn%d %s @(%.0f,%.0f)" % [mb.button_index, "DOWN" if mb.pressed else "UP", mb.position.x, mb.position.y]
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		return "touch idx=%d dev=%d %s @(%.0f,%.0f)" % [st.index, st.device, "DOWN" if st.pressed else "UP", st.position.x, st.position.y]
	return event.as_text()


func _describe_raw_event(event: InputEvent, source_tag: String) -> void:
	if event is InputEventKey:
		last_key_event_str = "[%s] %s" % [source_tag, _event_short(event)]
	elif event is InputEventMouseButton:
		last_mouse_event_str = "[%s] %s" % [source_tag, _event_short(event)]
	elif event is InputEventScreenTouch:
		last_touch_event_str = "[%s] %s" % [source_tag, _event_short(event)]


# ------------------------------------------------------------------------------
# Finalize: once the frame that received the event has run its physics ticks,
# classify where the event stopped and what the player did with it.
# ------------------------------------------------------------------------------
func _finalize_pending() -> void:
	if _pending_event == null:
		return
	var event := _pending_event
	_pending_event = null
	var is_press := _is_press(event)

	var verdict_code := "OK"
	var verdict := ""
	if not _pending_vp_delivered:
		verdict_code = "VIEWPORT_BLOCKED"
		verdict = "STOPPED AT S2: window got it, viewport did NOT deliver it to _input"
	if is_press and not _pending_actions.is_empty() and not _pending_singleton_ok:
		verdict_code = "INPUT_SINGLETON_BLOCKED"
		verdict = "STOPPED AT S3b: Input singleton disabled (Godot editor Game view Select/Suspend mode)"
	elif verdict_code == "OK" and event is InputEventKey and _pending_actions.is_empty():
		verdict_code = "UNMAPPED"
		verdict = "Key reached the game but is not bound to any gameplay action"
	if verdict_code == "OK":
		verdict = "Reached S2+S3 (viewport delivered, actions resolved, Input singleton live)"

	var player := _get_player()
	var p_info := "player=MISSING"
	if player != null:
		p_info = "S4 BUF %s axis=%.2f | S5/S6 state=%s vel=(%.0f,%.0f) phys=%s" % [
			player.debug_last_input_snapshot, Input.get_axis("move_left", "move_right"),
			PlayerController.State.keys()[player.current_state], player.velocity.x, player.velocity.y,
			str(player.can_process() and player.is_physics_processing())
		]
	if is_press or event is InputEventKey:
		last_verdict_code = verdict_code
		last_trace_verdict = verdict
	_log("TRACE %s -> %s | S2 VP delivered=%s | %s | %s" % [_event_short(event), verdict_code, str(_pending_vp_delivered), verdict, p_info])


func _process(_delta: float) -> void:
	if _pending_event != null and Engine.get_process_frames() > _pending_win_frame:
		_finalize_pending()

	if get_tree().paused != _was_paused:
		_was_paused = get_tree().paused
		var title := get_tree().current_scene.get_node_or_null("HudAndTouchUI/RootControl/OverlayPanel/VBox/OverlayTitle") as Label if get_tree().current_scene != null else null
		_log("TREE PAUSED -> %s overlay='%s'" % [str(_was_paused), title.text if title != null and _was_paused else ""])

	if _panel == null or not _panel.visible:
		return

	var vp := get_viewport()
	var win := get_window()
	var win_focused: bool = win.has_focus() if win != null else false
	var focus_owner: Control = vp.gui_get_focus_owner() if vp != null else null
	var focus_name: String = focus_owner.name if focus_owner != null else "None"

	var player := _get_player()
	var p_exists: bool = player != null
	var p_phys: bool = (player.can_process() and player.is_physics_processing()) if player != null else false
	var p_state: String = PlayerController.State.keys()[player.current_state] if player != null else "MISSING"
	var p_vel: Vector2 = player.velocity if player != null else Vector2.ZERO
	var p_buf: String = player.debug_last_input_snapshot if player != null else "-"

	var act_list: Array[String] = []
	for act in TRACKED_ACTIONS:
		if Input.is_action_pressed(act):
			act_list.append(act)
	var active_actions_str: String = ", ".join(act_list) if act_list.size() > 0 else "None"

	var warn_line: String = ""
	if last_verdict_code == "INPUT_SINGLETON_BLOCKED" or last_verdict_code == "VIEWPORT_BLOCKED":
		warn_line = "!! INPUT BLOCKED BEFORE GAME CODE (%s). In the editor Game tab click the\n   'Input' (gamepad) toggle / un-suspend, or run standalone. !!\n" % last_verdict_code

	_label.text = (
		warn_line
		+ "DIAG [F3] src:%s | Embedded:%s | WinFocus:%s | Paused:%s | GUIFocus:%s\n" % [event_source_tag, str(Engine.is_embedded_in_editor()), str(win_focused), str(get_tree().paused), focus_name]
		+ "S1 window events:%d  S2 viewport events:%d\n" % [win_event_count, vp_event_count]
		+ "Key: %s\n" % last_key_event_str
		+ "Mouse: %s\n" % last_mouse_event_str
		+ "Touch: %s\n" % last_touch_event_str
		+ "Verdict: %s\n" % last_trace_verdict
		+ "S3 Held InputMap: %s | Axis:%.2f\n" % [active_actions_str, Input.get_axis("move_left", "move_right")]
		+ "S4 Player buf: %s\n" % p_buf
		+ "S5 Player:%s Phys:%s State:%s Vel:(%.0f, %.0f)\n" % [str(p_exists), str(p_phys), p_state, p_vel.x, p_vel.y]
		+ "S6 Last state change: %s\n" % last_state_change_str
		+ "OnScreen: %s | %s" % [last_onscreen_btn_str, last_invoked_action_str]
	)
