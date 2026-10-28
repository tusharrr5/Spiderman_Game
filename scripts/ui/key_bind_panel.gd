class_name KeyBindPanel
extends PanelContainer
## Settings screen for remapping keys: two slots per action. Click (or focus + Enter) a slot, then press
## the new key. ESC cancels, BACKSPACE/DELETE clears the slot. Works while the game is paused.

signal closed

var _buttons: Dictionary = {}       # "action:slot" -> Button
var _listening: String = ""
var _status: Label
var _seen_change: int = -1


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "KeyBindPanel"
	add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.06, 0.13, 0.97), UIKit.ACCENT, 8, 2))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	add_child(vb)
	var title := UIKit.label("CONTROLS  -  SET YOUR OWN KEYS", 13, Color(1, 0.88, 0.45), 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	vb.add_child(grid)
	for row in KeyBindings.ACTIONS:
		var a: String = row[0]
		var l := UIKit.label(String(row[1]), 9, Color(1, 0.8, 0.8), 3)
		l.custom_minimum_size = Vector2(150, 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(l)
		for s in range(KeyBindings.SLOTS):
			var b := UIKit.button("", 8, Vector2(86, 15))
			_compact(b)
			b.name = "Key_%s_%d" % [a, s]
			b.pressed.connect(_listen.bind(a, s))
			grid.add_child(b)
			_buttons["%s:%d" % [a, s]] = b
	_status = UIKit.label("", 8, Color(0.75, 0.85, 1.0), 3)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_status)
	var help := UIKit.label("Moves: hold DOWN = block (just before a hit = PARRY)  |  hold PUNCH = heavy  |  DODGE then PUNCH = dash strike\nSPECIAL = 1 bar, UP+SPECIAL = 2 bars, DOWN+SPECIAL = 3 bars  |  hold SPECIAL with an empty meter = charge", 7, Color(0.7, 0.75, 0.9), 3)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(help)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	var reset := UIKit.button("RESET DEFAULTS", 9, Vector2(120, 18))
	_compact(reset)
	reset.name = "ResetKeys"
	reset.pressed.connect(func() -> void:
		_listening = ""
		KeyBindings.reset_defaults()
		_status.text = "Default keys restored.")
	hb.add_child(reset)
	var close := UIKit.button("DONE", 9, Vector2(100, 18))
	_compact(close)
	close.name = "CloseKeys"
	close.pressed.connect(close_panel)
	hb.add_child(close)
	visible = false


func open() -> void:
	_listening = ""
	_status.text = "Click a key slot, then press the new key."
	_refresh()
	visible = true
	reset_size()
	_center.call_deferred()
	(_buttons["%s:0" % KeyBindings.ACTIONS[0][0]] as Button).grab_focus()


func _center() -> void:
	reset_size()
	var vp := get_viewport_rect().size
	position = ((Vector2(maxf(640.0, vp.x), maxf(360.0, vp.y)) - size) * 0.5).floor()


## Thin version of the shared button style so 12 rows fit on the 360 px tall screen.
static func _compact(b: Button) -> void:
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb := (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		b.add_theme_stylebox_override(st, sb)


func close_panel() -> void:
	_listening = ""
	visible = false
	closed.emit()


func _listen(action: String, slot: int) -> void:
	_listening = "%s:%d" % [action, slot]
	_refresh()
	_status.text = "Press a key for  %s  (ESC cancels, BACKSPACE clears)" % _label_of(action).to_upper()


func _label_of(action: String) -> String:
	for row in KeyBindings.ACTIONS:
		if row[0] == action:
			return String(row[1])
	return action


func _refresh() -> void:
	_seen_change = KeyBindings.changed_count
	for key in _buttons:
		var parts := String(key).split(":")
		var b: Button = _buttons[key]
		b.text = "..." if key == _listening else KeyBindings.key_name(KeyBindings.get_key(parts[0], int(parts[1])))


func _process(_delta: float) -> void:
	if visible and _seen_change != KeyBindings.changed_count:
		_refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if _listening == "":
		if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			close_panel()
			get_viewport().set_input_as_handled()
		return
	if key == null or not key.pressed or key.echo:
		if event is InputEventMouseButton or event is InputEventJoypadButton:
			return
		if key != null:
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	var parts := _listening.split(":")
	var action: String = parts[0]
	var slot := int(parts[1])
	_listening = ""
	var code := int(key.physical_keycode) if key.physical_keycode != KEY_NONE else int(key.keycode)
	if code == KEY_ESCAPE:
		_status.text = "Cancelled."
	elif code == KEY_BACKSPACE or code == KEY_DELETE:
		KeyBindings.clear_key(action, slot)
		_status.text = "%s slot cleared." % _label_of(action)
	else:
		var moved := KeyBindings.set_key(action, slot, code)
		_status.text = "%s = %s" % [_label_of(action), KeyBindings.key_name(code)]
		if moved != "":
			_status.text += "   (swapped with %s)" % moved
	_refresh()
	(_buttons["%s:%d" % [action, slot]] as Button).grab_focus()
