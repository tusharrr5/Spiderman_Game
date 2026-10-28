extends Control
## Arena hub: Gauntlet tiers, endless Survival, the Daily Challenge, records and the token balance.

var _tier: int = 1
var _tier_label: Label


func _ready() -> void:
	UIKit.full_rect(self)
	UIKit.backdrop(self, "res://assets/ui/title_bg.jpg", 0.55)
	var title := UIKit.label("NIGHT ARENA", 30, Color(0.96, 0.25, 0.3), 8)
	title.position = Vector2(24, 14)
	add_child(title)
	var tok := UIKit.label("TOKENS  %d" % GameState.tokens, 12, Color(1, 0.85, 0.35), 4)
	tok.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tok.position = Vector2(-150, 22)
	add_child(tok)

	var best_tier := int(GameState.arena_best.get("gauntlet", 0))
	_tier = best_tier + 1
	var row := HBoxContainer.new()
	row.position = Vector2(24, 64)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	row.add_child(_card("GAUNTLET", "Four rounds: the gang, the Thief, Brick and the Goblin.\nHealth carries over. Each tier is tougher and pays more.\nBest tier cleared: %d" % best_tier, "gauntlet"))
	row.add_child(_card("SURVIVAL", "Endless waves with a boss every 5th wave.\nHow long can you last?\nBest: wave %d   |   score %d" % [int(GameState.arena_best.get("survival", 0)), int(GameState.arena_best.get("survival_score", 0))], "survival"))
	var done := GameState.daily_done == GameState.today_key()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(GameState.today_key())
	var mod: Array = ArenaLevel.MODIFIERS.values()[rng.randi_range(0, ArenaLevel.MODIFIERS.size() - 1)]
	row.add_child(_card("DAILY CHALLENGE", "Today's rule: %s\n%s\n%s   |   streak %d" % [mod[0], mod[1], "CLEARED TODAY" if done else "Bonus tokens on first clear", GameState.daily_streak], "daily"))

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(24, 312)
	bottom.add_theme_constant_override("separation", 10)
	add_child(bottom)
	var shop := UIKit.button("UPGRADES & SUITS", 11, Vector2(170, 28))
	shop.pressed.connect(GameState.goto_shop)
	bottom.add_child(shop)
	var back := UIKit.button("BACK", 11, Vector2(110, 28))
	back.pressed.connect(GameState.goto_title)
	bottom.add_child(back)
	Audio.play_music("title_theme")


func _card(name: String, desc: String, mode: String) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(190, 236)
	p.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL, UIKit.ACCENT if mode != "daily" else Color(1, 0.8, 0.3), 8, 2))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	vb.add_child(UIKit.label(name, 15, Color(1, 0.9, 0.6)))
	var d := UIKit.label(desc, 8, Color(0.88, 0.9, 1.0), 3)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(170, 110)
	vb.add_child(d)
	if mode == "gauntlet":
		var tr := HBoxContainer.new()
		var minus := UIKit.button("-", 12, Vector2(30, 24))
		_tier_label = UIKit.label("TIER %d" % _tier, 11, Color(1, 1, 1), 3)
		_tier_label.custom_minimum_size = Vector2(80, 20)
		_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plus := UIKit.button("+", 12, Vector2(30, 24))
		minus.pressed.connect(func() -> void: _set_tier(_tier - 1))
		plus.pressed.connect(func() -> void: _set_tier(_tier + 1))
		tr.add_child(minus)
		tr.add_child(_tier_label)
		tr.add_child(plus)
		vb.add_child(tr)
	var go := UIKit.button("FIGHT", 13, Vector2(170, 32))
	go.name = "Fight_" + mode
	go.pressed.connect(func() -> void: GameState.start_arena(mode, _tier if mode == "gauntlet" else 1))
	vb.add_child(go)
	if mode == "gauntlet":
		go.call_deferred("grab_focus")
	return p


func _set_tier(t: int) -> void:
	_tier = clampi(t, 1, int(GameState.arena_best.get("gauntlet", 0)) + 1)
	_tier_label.text = "TIER %d" % _tier


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		GameState.goto_title()
