extends Control
## Title screen: STORY MODE (continue / new game / level select), VERSUS (1v1 / 3v3), Night Arena,
## Upgrades & Suits, Challenges, Controls & Keys, Credits, Quit (desktop only). Shows the daily login reward.

var _controls: KeyBindPanel
var _confirm: ConfirmationDialog
var _controls_btn: Button


func _ready() -> void:
	UIKit.full_rect(self)
	UIKit.backdrop(self, "res://assets/ui/title_bg.jpg")
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.08, 0.35)
	shade.size = Vector2(300, 360)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := UIKit.label("WEB-SLINGER", 40, Color(0.96, 0.22, 0.28), 10)
	title.position = Vector2(24, 26)
	add_child(title)
	var sub := UIKit.label("NIGHT PATROL", 22, Color(0.95, 0.95, 1.0), 8)
	sub.position = Vector2(28, 76)
	add_child(sub)
	var tag := UIKit.label("A fan-made side-scrolling web-slinging adventure", 8, Color(0.75, 0.8, 0.95), 4)
	tag.position = Vector2(30, 108)
	add_child(tag)

	# main menu: STORY MODE opens the campaign sub-menu; VERSUS is the 1v1 / 3v3 fighting mode
	var vb := VBoxContainer.new()
	vb.name = "MainMenu"
	vb.position = Vector2(30, 128)
	vb.add_theme_constant_override("separation", 5)
	add_child(vb)
	var story_vb := VBoxContainer.new()
	story_vb.name = "StoryMenu"
	story_vb.position = Vector2(30, 128)
	story_vb.add_theme_constant_override("separation", 7)
	story_vb.visible = false
	add_child(story_vb)

	var bs := Vector2(180, 26)
	var story := UIKit.button("STORY MODE", 12, bs)
	story.name = "StoryButton"
	vb.add_child(story)
	var versus := UIKit.button("VERSUS  1v1 / 3v3", 12, bs)
	versus.name = "VersusButton"
	versus.pressed.connect(GameState.goto_versus_setup)
	vb.add_child(versus)
	var arena := UIKit.button("NIGHT ARENA" if GameState.is_arena_unlocked() else "NIGHT ARENA  (clear Ch.1)", 12, bs)
	arena.name = "ArenaButton"
	arena.disabled = not GameState.is_arena_unlocked()
	arena.pressed.connect(GameState.goto_arena_hub)
	vb.add_child(arena)
	var shop := UIKit.button("SHOP: UPGRADES, SUITS, BOOSTS", 11, bs)
	shop.pressed.connect(GameState.goto_shop.bind("title"))
	vb.add_child(shop)
	var done := 0
	for c in GameState.CHALLENGES:
		if c[0] in GameState.challenges_claimed:
			done += 1
	var chal := UIKit.button("CHALLENGES  %d / %d" % [done, GameState.CHALLENGES.size()], 12, bs)
	chal.name = "ChallengesButton"
	chal.pressed.connect(func() -> void: _open_challenges(chal))
	vb.add_child(chal)
	var ctr := UIKit.button("CONTROLS & KEYS", 12, bs)
	ctr.name = "ControlsButton"
	ctr.pressed.connect(func() -> void: _controls.open())
	_controls_btn = ctr
	vb.add_child(ctr)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 5)
	vb.add_child(small)
	var cred := UIKit.button("CREDITS", 10, Vector2(87, 22))
	cred.pressed.connect(GameState.goto_credits)
	small.add_child(cred)
	if OS.get_name() != "Web" and OS.get_name() != "Android" and OS.get_name() != "iOS":
		var quit := UIKit.button("QUIT", 10, Vector2(88, 22))
		quit.pressed.connect(func() -> void: get_tree().quit())
		small.add_child(quit)
	var first: Button = story

	var story_title := UIKit.label("STORY MODE", 12, Color(1, 0.85, 0.45), 4)
	story_vb.add_child(story_title)
	var story_first: Button
	if GameState.has_any_progress():
		var cont := UIKit.button("CONTINUE  -  CHAPTER %d" % GameState.highest_unlocked, 12, Vector2(180, 26))
		cont.pressed.connect(func() -> void: GameState.start_level(GameState.highest_unlocked))
		story_vb.add_child(cont)
		story_first = cont
	var newg := UIKit.button("NEW GAME" if not GameState.has_any_progress() else "PLAY FROM CHAPTER 1", 12, Vector2(180, 26))
	newg.name = "NewGameButton"
	newg.pressed.connect(func() -> void: GameState.start_level(1))
	story_vb.add_child(newg)
	if story_first == null:
		story_first = newg
	var sel := UIKit.button("LEVEL SELECT")
	sel.pressed.connect(GameState.goto_level_select)
	story_vb.add_child(sel)
	var back := UIKit.button("BACK")
	story_vb.add_child(back)
	story.pressed.connect(func() -> void:
		vb.visible = false
		story_vb.visible = true
		story_first.grab_focus())
	back.pressed.connect(func() -> void:
		story_vb.visible = false
		vb.visible = true
		story.grab_focus())
	var tok := UIKit.label("TOKENS %d   |   STARS %d / 15" % [GameState.tokens, GameState.total_stars()], 9, Color(1, 0.85, 0.35), 4)
	tok.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tok.position = Vector2(-200, 12)
	add_child(tok)

	var ver := UIKit.label("v1.0  |  Unofficial fan project  |  Built with Godot", 7, Color(0.7, 0.72, 0.85), 3)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(8, 344)
	add_child(ver)
	_build_controls_panel()
	first.call_deferred("grab_focus")
	var reward := GameState.claim_daily_login()
	if not reward.is_empty():
		_show_daily_reward(reward, tok)
	Audio.play_music("title_theme")


func _build_controls_panel() -> void:
	_controls = KeyBindPanel.new()
	add_child(_controls)
	_controls.closed.connect(func() -> void: _controls_btn.grab_focus())


## Daily login reward card: a 7-day track with today's tokens and any boosts.
func _show_daily_reward(reward: Dictionary, tok: Label) -> void:
	tok.text = "TOKENS %d   |   STARS %d / 15" % [GameState.tokens, GameState.total_stars()]
	var p := PanelContainer.new()
	p.name = "DailyReward"
	p.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.06, 0.13, 0.97), Color(1, 0.8, 0.3), 8, 2))
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	var t := UIKit.label("DAILY REWARD  -  DAY %d" % int(reward["day"]), 16, Color(1, 0.85, 0.35), 5)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var track := HBoxContainer.new()
	track.add_theme_constant_override("separation", 4)
	track.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(track)
	for d in range(1, 8):
		var cell := PanelContainer.new()
		var today := d == int(reward["day"])
		var col := Color(1, 0.8, 0.3) if today else (Color(0.35, 0.8, 0.45) if d < int(reward["day"]) else Color(0.3, 0.32, 0.45))
		cell.add_theme_stylebox_override("panel", UIKit.box(Color(0.08, 0.09, 0.18, 0.95), col, 4, 2 if today else 1))
		cell.custom_minimum_size = Vector2(46, 40)
		var l := UIKit.label("DAY %d\n%d%s" % [d, 40 + 20 * d, "\n+BOOST" if d in [3, 5, 7] else ""], 7, col, 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		track.add_child(cell)
	var got := "+%d TOKENS" % int(reward["tokens"])
	for b in reward["boosts"]:
		got += "   +" + String(GameState.BOOSTS[String(b)][0])
	var g := UIKit.label(got, 11, Color(0.75, 1.0, 0.8), 4)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(g)
	var s := UIKit.label("Login streak: %d day%s. Come back tomorrow for more!" % [int(reward["streak"]), "" if int(reward["streak"]) == 1 else "s"], 8, Color(0.8, 0.85, 1.0), 3)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	var ok := UIKit.button("COLLECT", 12, Vector2(140, 26))
	ok.name = "CollectReward"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ok)
	p.reset_size()
	p.position = ((Vector2(640, 360) - p.size) * 0.5).floor()
	var prev := get_viewport().gui_get_focus_owner()
	ok.pressed.connect(func() -> void:
		Audio.play_sfx("pickup", 0.8)
		p.queue_free()
		if is_instance_valid(prev):
			prev.grab_focus())
	ok.call_deferred("grab_focus")
	Audio.play_sfx("pickup", 0.7)


## Challenge list with progress bars; rewards pay out automatically after versus matches.
func _open_challenges(from: Button) -> void:
	var p := PanelContainer.new()
	p.name = "Challenges"
	p.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.06, 0.13, 0.97), UIKit.ACCENT, 8, 2))
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	var t := UIKit.label("CHALLENGES", 14, Color(1, 0.85, 0.4), 4)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	for c in GameState.CHALLENGES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vb.add_child(row)
		var done: bool = c[0] in GameState.challenges_claimed
		var val := mini(GameState.challenge_value(String(c[2])), int(c[3]))
		var l := UIKit.label(("✓ " if done else "") + String(c[1]), 7, Color(0.5, 1.0, 0.6) if done else Color(0.92, 0.94, 1.0), 3)
		l.custom_minimum_size = Vector2(250, 0)
		row.add_child(l)
		var bg := ColorRect.new()
		bg.color = Color(0.1, 0.1, 0.18)
		bg.custom_minimum_size = Vector2(70, 5)
		bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bg)
		var fill := ColorRect.new()
		fill.color = Color(0.4, 1.0, 0.5) if done else Color(1, 0.75, 0.3)
		fill.size = Vector2(70.0 * float(val) / float(c[3]), 5)
		bg.add_child(fill)
		row.add_child(UIKit.label("%d/%d" % [val, int(c[3])], 7, Color(0.8, 0.85, 1.0), 3))
		row.add_child(UIKit.label("+%d" % int(c[4]), 7, Color(1, 0.85, 0.35), 3))
	var close := UIKit.button("CLOSE", 11, Vector2(110, 22))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(close)
	p.reset_size()
	p.position = ((Vector2(640, 360) - p.size) * 0.5).floor()
	close.pressed.connect(func() -> void:
		p.queue_free()
		from.grab_focus())
	close.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if _controls.visible:
		return
	if has_node("Challenges") and event.is_action_pressed("pause_game"):
		get_node("Challenges").queue_free()
		return
	if event.is_action_pressed("pause_game") and has_node("StoryMenu") and get_node("StoryMenu").visible:
		get_node("StoryMenu").visible = false
		get_node("MainMenu").visible = true
