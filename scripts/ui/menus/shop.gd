extends Control
## Shop: spend tokens on permanent story upgrades, suit colourways and versus boosts (consumables).

var _tokens: Label
var _list: VBoxContainer
var _preview: SpriteAnimator
var _boosts: VBoxContainer


func _ready() -> void:
	UIKit.full_rect(self)
	UIKit.backdrop(self, "res://assets/ui/title_bg.jpg", 0.6)
	var title := UIKit.label("SHOP", 26, Color(0.96, 0.25, 0.3), 8)
	title.position = Vector2(24, 12)
	add_child(title)
	_tokens = UIKit.label("", 12, Color(1, 0.85, 0.35), 4)
	_tokens.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tokens.position = Vector2(-150, 20)
	add_child(_tokens)
	_list = VBoxContainer.new()
	_list.position = Vector2(24, 56)
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)

	var stage := ColorRect.new()
	stage.color = Color(0.04, 0.05, 0.1, 0.75)
	stage.position = Vector2(470, 56)
	stage.size = Vector2(150, 118)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var anim := SpriteAnimator.new()
	_preview = anim
	add_child(anim)
	anim.setup("hero_classic", 0.0)
	anim.scale *= 2.0
	anim.position = Vector2(545, 128)
	_boosts = VBoxContainer.new()
	_boosts.position = Vector2(470, 180)
	_boosts.add_theme_constant_override("separation", 3)
	add_child(_boosts)

	var back := UIKit.button("BACK", 11, Vector2(110, 28))
	back.position = Vector2(24, 318)
	back.pressed.connect(_back)
	add_child(back)
	GameState.progress_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_tokens.text = "TOKENS  %d" % GameState.tokens
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(UIKit.label("UPGRADES", 12, Color(1, 0.9, 0.6), 3))
	for key in GameState.UPGRADES:
		var info: Array = GameState.UPGRADES[key]
		var lvl := GameState.get_upgrade(key)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var pips := ""
		for i in range(GameState.UPGRADE_MAX):
			pips += "■" if i < lvl else "□"
		var l := UIKit.label("%-9s %s  %s" % [info[0], pips, info[1]], 8, Color(0.9, 0.92, 1.0), 3)
		l.custom_minimum_size = Vector2(300, 22)
		row.add_child(l)
		var maxed := lvl >= GameState.UPGRADE_MAX
		var b := UIKit.button("MAX" if maxed else "BUY %d" % GameState.upgrade_cost(key), 9, Vector2(90, 22))
		b.name = "Buy_" + key
		b.disabled = maxed or GameState.tokens < GameState.upgrade_cost(key)
		b.pressed.connect(func() -> void: GameState.buy_upgrade(key))
		row.add_child(b)
		_list.add_child(row)
	_list.add_child(UIKit.label("SUITS", 12, Color(1, 0.9, 0.6), 3))
	for key in GameState.SUITS:
		var info: Array = GameState.SUITS[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var owned := GameState.owns_suit(key)
		var equipped: bool = GameState.suit_equipped == key
		var l := UIKit.label(String(info[0]), 9, Color(0.9, 0.92, 1.0), 3)
		l.custom_minimum_size = Vector2(200, 22)
		row.add_child(l)
		var prev := UIKit.button("VIEW", 9, Vector2(60, 22))
		prev.pressed.connect(func() -> void: _show_suit(key))
		row.add_child(prev)
		var b: Button
		if key == "dark" and not owned:
			b = UIKit.button("STORY UNLOCK", 9, Vector2(110, 22))
			b.disabled = true
		elif not owned:
			b = UIKit.button("BUY %d" % int(info[1]), 9, Vector2(110, 22))
			b.disabled = GameState.tokens < int(info[1])
			b.pressed.connect(func() -> void: GameState.buy_suit(key))
		else:
			b = UIKit.button("EQUIPPED" if equipped else "EQUIP", 9, Vector2(110, 22))
			b.disabled = equipped
			b.pressed.connect(func() -> void:
				GameState.equip_suit(key)
				_show_suit(key))
		b.name = "Suit_" + key
		row.add_child(b)
		_list.add_child(row)
	for c in _boosts.get_children():
		c.queue_free()
	_boosts.add_child(UIKit.label("VERSUS BOOSTS", 12, Color(1, 0.9, 0.6), 3))
	for key in GameState.BOOSTS:
		var info: Array = GameState.BOOSTS[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var l := UIKit.label("%s x%d" % [String(info[0]).replace(" BOOST", ""), int(GameState.boosts.get(key, 0))], 8, info[3], 3)
		l.custom_minimum_size = Vector2(80, 18)
		l.tooltip_text = String(info[1])
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		var b := UIKit.button("BUY %d" % int(info[2]), 8, Vector2(66, 18))
		b.name = "BuyBoost_" + key
		b.tooltip_text = String(info[1])
		b.disabled = GameState.tokens < int(info[2])
		b.pressed.connect(func() -> void:
			GameState.buy_boost(key)
			_rebuild())
		row.add_child(b)
		_boosts.add_child(row)
	_show_suit(GameState.suit_equipped)


func _show_suit(key: String) -> void:
	var anim := _preview as SpriteAnimator
	anim.swap_sheet("hero_dark" if key == "dark" else "hero_classic")
	if PlayerController.SUIT_TINTS.has(key):
		var m := ShaderMaterial.new()
		m.shader = PlayerController.SUIT_TINT
		var t: Array = PlayerController.SUIT_TINTS[key]
		m.set_shader_parameter("primary_to", Vector3(t[0].r, t[0].g, t[0].b))
		m.set_shader_parameter("secondary_to", Vector3(t[1].r, t[1].g, t[1].b))
		anim.material = m
	else:
		anim.material = null
	anim.play("idle", true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_back()


func _back() -> void:
	if GameState.shop_return == "title" or not GameState.is_arena_unlocked():
		GameState.goto_title()
	else:
		GameState.goto_arena_hub()
