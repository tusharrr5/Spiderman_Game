class_name KeyBindings
extends RefCounted
## Player-remappable keyboard controls. Every gameplay action has two key slots; changes are saved to
## user://keybinds.cfg and applied to the InputMap at startup (GameState._ready). Joypad and touch
## bindings are never touched. Hints and help text use fill() so they always show the current keys.

## Tests point this at a scratch file so they never touch the player's real bindings.
static var save_path: String = "user://keybinds.cfg"
const SLOTS: int = 2
## [action, label] in the order shown on the settings screen
const ACTIONS: Array = [
	["move_left", "Move left"], ["move_right", "Move right"], ["climb_up", "Up / Climb"], ["climb_down", "Down / Block"],
	["jump", "Jump"], ["attack_punch", "Punch (hold = Heavy)"], ["attack_kick", "Kick"], ["web_action", "Web shot / Swing"],
	["special_action", "Special / Throw"], ["dodge", "Dodge / Dash"], ["suit_toggle", "Suit / Tag partner"], ["pause_game", "Pause"],
]
## {token} -> action used by fill(); {move} is both move keys
const TOKENS: Dictionary = {
	"up": "climb_up", "down": "climb_down", "left": "move_left", "right": "move_right", "jump": "jump",
	"punch": "attack_punch", "kick": "attack_kick", "web": "web_action", "special": "special_action",
	"dodge": "dodge", "suit": "suit_toggle", "pause": "pause_game",
}

static var _defaults: Dictionary = {}     # action -> Array[int] keycodes from project.godot
static var _current: Dictionary = {}      # action -> Array[int] (0 = empty slot)
static var changed_count: int = 0         # bumps on every change so open screens can refresh


## Snapshot the project defaults, then apply any saved overrides.
static func load_and_apply() -> void:
	_capture_defaults()
	_current = _defaults.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		for row in ACTIONS:
			var a: String = row[0]
			if cfg.has_section_key("keys", a):
				var saved: Array = cfg.get_value("keys", a, [])
				var keys: Array = []
				for i in range(SLOTS):
					keys.append(int(saved[i]) if i < saved.size() else 0)
				_current[a] = keys
	_apply_all()


static func _capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for row in ACTIONS:
		var a: String = row[0]
		var keys: Array = []
		if InputMap.has_action(a):
			for ev in InputMap.action_get_events(a):
				if ev is InputEventKey:
					var code := _code_of(ev as InputEventKey)
					if code != 0 and not keys.has(code):
						keys.append(code)
		while keys.size() < SLOTS:
			keys.append(0)
		_defaults[a] = keys.slice(0, SLOTS)


static func _code_of(ev: InputEventKey) -> int:
	return int(ev.physical_keycode) if ev.physical_keycode != KEY_NONE else int(ev.keycode)


static func _apply_all() -> void:
	for row in ACTIONS:
		_apply(String(row[0]))


## Replace the action's keyboard events; each key is bound by keycode and physical keycode like project.godot.
static func _apply(action: String) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	for code in _current.get(action, []):
		if int(code) == 0:
			continue
		var by_label := InputEventKey.new()
		by_label.keycode = int(code)
		InputMap.action_add_event(action, by_label)
		var by_pos := InputEventKey.new()
		by_pos.physical_keycode = int(code)
		InputMap.action_add_event(action, by_pos)


static func get_key(action: String, slot: int) -> int:
	var keys: Array = _current.get(action, [])
	return int(keys[slot]) if slot < keys.size() else 0


## Bind `code` to action/slot. If another slot already uses the key it receives this slot's old key
## (a swap), so no key is ever bound twice. Returns the label of the action that gave the key up, or "".
static func set_key(action: String, slot: int, code: int) -> String:
	var old := get_key(action, slot)
	var moved_from := ""
	for row in ACTIONS:
		var a: String = row[0]
		var keys: Array = _current[a]
		for i in range(SLOTS):
			if int(keys[i]) == code and not (a == action and i == slot):
				keys[i] = old
				if a != action:
					moved_from = String(row[1])
				_apply(a)
	_current[action][slot] = code
	_apply(action)
	_save()
	changed_count += 1
	return moved_from


static func clear_key(action: String, slot: int) -> void:
	_current[action][slot] = 0
	_apply(action)
	_save()
	changed_count += 1


static func reset_defaults() -> void:
	_current = _defaults.duplicate(true)
	_apply_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	changed_count += 1


static func is_default() -> bool:
	return _current == _defaults


static func _save() -> void:
	var cfg := ConfigFile.new()
	for row in ACTIONS:
		cfg.set_value("keys", String(row[0]), _current[String(row[0])])
	cfg.save(save_path)


static func key_name(code: int) -> String:
	if code == 0:
		return "-"
	match code:
		KEY_SPACE: return "SPACE"
		KEY_ESCAPE: return "ESC"
		KEY_SHIFT: return "SHIFT"
		KEY_CTRL: return "CTRL"
		KEY_ALT: return "ALT"
		KEY_LEFT: return "LEFT"
		KEY_RIGHT: return "RIGHT"
		KEY_UP: return "UP"
		KEY_DOWN: return "DOWN"
		KEY_ENTER: return "ENTER"
		KEY_TAB: return "TAB"
		KEY_BACKSPACE: return "BKSP"
	return OS.get_keycode_string(code).to_upper()


## Primary key name for an action (falls back to the second slot), e.g. "K".
static func k(action: String) -> String:
	var a := get_key(action, 0)
	return key_name(a if a != 0 else get_key(action, 1))


## Both keys, e.g. "K / Q" or "K".
static func both(action: String) -> String:
	var parts: Array = []
	for i in range(SLOTS):
		if get_key(action, i) != 0:
			parts.append(key_name(get_key(action, i)))
	return " / ".join(parts) if not parts.is_empty() else "-"


## Replace {jump}, {punch}, {move}... with the current key names.
static func fill(text: String) -> String:
	if text.find("{") < 0:
		return text
	var out := text.replace("{move}", "%s/%s" % [k("move_left"), k("move_right")])
	for t in TOKENS:
		out = out.replace("{%s}" % t, k(String(TOKENS[t])))
	return out
