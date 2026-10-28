extends Control
## Versus setup: page 1 picks the mode (1 VS 1, 3 VS 3, CPU VS CPU), difficulty and stage; page 2 is the
## 20-fighter select grid with a live preview, stats, passive and specials. The bot then drafts its team
## from the same roster (shown with a quick shuffle) and the match starts.

const DIFFS: Array[String] = ["easy", "moderate", "difficult", "more_difficult"]

var mode: String = "1v1"
var difficulty: String = "moderate"
var stage: String = "random"
var picks: Array = []
var bot_picks: Array = []
var _page1: Control
var _page2: Control
var _mode_btns: Dictionary = {}
var _diff_btns: Dictionary = {}
var _stage_btn: Button
var _cells: Dictionary = {}
var _team_row: HBoxContainer
var _bot_row: HBoxContainer
var _fight: Button
var _preview: SpriteAnimator
var _info: Label
var _name: Label
var _bars: Dictionary = {}
var _hint: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	UIKit.full_rect(self)
	UIKit.backdrop(self, "res://assets/ui/title_bg.jpg", 0.62)
	var last: Dictionary = GameState.versus_config
	mode = String(last.get("mode", "1v1"))
	difficulty = String(last.get("difficulty", "moderate"))
	stage = String(last.get("stage", "random"))
	_build_page1()
	_build_page2()
	_show_page(1)
	Audio.play_music("title_theme")


# ------------------------------------------------------------------ page 1: mode / difficulty / stage
func _build_page1() -> void:
	_page1 = Control.new()
	UIKit.full_rect(_page1)
	add_child(_page1)
	var title := UIKit.label("VERSUS", 32, Color(0.96, 0.25, 0.3), 8)
	title.position = Vector2(24, 12)
	_page1.add_child(title)
	var v := GameState.versus_stats
	var rec := UIKit.label("WINS %d   LOSSES %d   STREAK %d   BEST %d   |   TOKENS %d" % [int(v.get("wins", 0)), int(v.get("losses", 0)),
		int(v.get("streak", 0)), int(v.get("best_streak", 0)), GameState.tokens], 8, Color(1, 0.85, 0.4), 3)
	rec.position = Vector2(28, 56)
	_page1.add_child(rec)
	var vb := VBoxContainer.new()
	vb.position = Vector2(28, 76)
	vb.add_theme_constant_override("separation", 6)
	_page1.add_child(vb)
	vb.add_child(UIKit.label("MODE", 11, Color(1, 0.9, 0.6), 3))
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 6)
	vb.add_child(mr)
	for m in [["1v1", "1 VS 1"], ["3v3", "3 VS 3  (team elimination)"], ["cpu", "CPU VS CPU  (watch)"]]:
		var b := UIKit.button(m[1], 10, Vector2(150 if m[0] != "1v1" else 90, 28))
		b.name = "Mode_" + m[0]
		b.toggle_mode = true
		b.pressed.connect(_set_mode.bind(m[0]))
		mr.add_child(b)
		_mode_btns[m[0]] = b
	vb.add_child(UIKit.label("DIFFICULTY", 11, Color(1, 0.9, 0.6), 3))
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 6)
	vb.add_child(dr)
	for d in DIFFS:
		var b := UIKit.button(FighterAI.NAMES[d], 10, Vector2(118, 28))
		b.name = "Diff_" + d
		b.toggle_mode = true
		b.pressed.connect(_set_diff.bind(d))
		dr.add_child(b)
		_diff_btns[d] = b
	var desc := UIKit.label("", 8, Color(0.85, 0.88, 1.0), 3)
	desc.name = "DiffDesc"
	vb.add_child(desc)
	vb.add_child(UIKit.label("STAGE", 11, Color(1, 0.9, 0.6), 3))
	_stage_btn = UIKit.button("", 10, Vector2(220, 28))
	_stage_btn.pressed.connect(_cycle_stage)
	vb.add_child(_stage_btn)
	var row := HBoxContainer.new()
	row.position = Vector2(28, 312)
	row.add_theme_constant_override("separation", 10)
	_page1.add_child(row)
	var go := UIKit.button("CHOOSE FIGHTERS  >", 12, Vector2(200, 30))
	go.name = "Next"
	go.pressed.connect(func() -> void: _show_page(2))
	row.add_child(go)
	var back := UIKit.button("BACK", 11, Vector2(100, 30))
	back.pressed.connect(GameState.goto_title)
	row.add_child(back)
	_set_mode(mode)
	_set_diff(difficulty)
	_update_stage()
	go.call_deferred("grab_focus")


func _set_mode(m: String) -> void:
	mode = m
	for k in _mode_btns:
		(_mode_btns[k] as Button).button_pressed = k == m
	picks.clear()
	_refresh_team()


func _set_diff(d: String) -> void:
	difficulty = d
	for k in _diff_btns:
		(_diff_btns[k] as Button).button_pressed = k == d
	var text := {"easy": "Slow reactions, rarely blocks, light damage. Great for learning.",
		"moderate": "Blocks sometimes, short combos, uses specials when it has power.",
		"difficult": "Quick reactions, parries, dash-ins, 3-hit combos and tag-outs.",
		"more_difficult": "Near-instant reactions, frequent parries, heavies and full specials."}
	var desc := _page1.find_child("DiffDesc", true, false) as Label
	if desc:
		desc.text = text[d]


func _cycle_stage() -> void:
	var opts: Array = ["random"] + Array(VersusLevel.STAGES)
	stage = opts[(opts.find(stage) + 1) % opts.size()]
	_update_stage()


func _update_stage() -> void:
	_stage_btn.text = "< %s >" % ("RANDOM" if stage == "random" else String(VersusLevel.STAGE_NAMES[stage]))


func team_size() -> int:
	return 3 if mode in ["3v3", "cpu"] else 1


# ------------------------------------------------------------------ page 2: fighter select
func _build_page2() -> void:
	_page2 = Control.new()
	UIKit.full_rect(_page2)
	add_child(_page2)
	var title := UIKit.label("CHOOSE YOUR FIGHTER", 20, Color(0.96, 0.25, 0.3), 6)
	title.position = Vector2(20, 6)
	title.name = "Title"
	_page2.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.position = Vector2(20, 36)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_page2.add_child(grid)
	for key in SpiderRoster.ORDER:
		var info := SpiderRoster.info(key)
		var b := Button.new()
		b.name = "Pick_" + key
		b.custom_minimum_size = Vector2(56, 56)
		b.icon = load(String(info["portrait"]))
		b.expand_icon = true
		b.tooltip_text = String(info["name"])
		UIKit.style_button(b, 7)
		b.pressed.connect(_pick.bind(key))
		b.focus_entered.connect(_show_info.bind(key))
		b.mouse_entered.connect(_show_info.bind(key))
		var wins := int(GameState.char_wins.get(key, 0))
		if wins > 0:
			var star := UIKit.label("★%d" % wins, 7, Color(1, 0.85, 0.3), 3)
			star.position = Vector2(2, 44)
			b.add_child(star)
		grid.add_child(b)
		_cells[key] = b
	# preview + info
	var stagebg := ColorRect.new()
	stagebg.color = Color(0.04, 0.05, 0.1, 0.8)
	stagebg.position = Vector2(20, 158)
	stagebg.size = Vector2(110, 150)
	stagebg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page2.add_child(stagebg)
	_preview = SpriteAnimator.new()
	_page2.add_child(_preview)
	_preview.setup("hero_classic", 0.0)
	_preview.scale *= 2.2
	_preview.position = Vector2(75, 236)
	_name = UIKit.label("", 13, Color(1, 0.92, 0.7), 4)
	_name.position = Vector2(140, 158)
	_page2.add_child(_name)
	for i in range(4):
		var stat: String = ["HP", "POWER", "SPEED", "DEFENSE"][i]
		var l := UIKit.label(stat, 7, Color(0.8, 0.85, 1.0), 3)
		l.position = Vector2(140, 178 + i * 11)
		_page2.add_child(l)
		var bg := ColorRect.new()
		bg.color = Color(0.06, 0.06, 0.12, 0.9)
		bg.position = Vector2(190, 181 + i * 11)
		bg.size = Vector2(90, 5)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_page2.add_child(bg)
		var fill := ColorRect.new()
		fill.color = [Color(0.3, 0.9, 0.4), Color(1, 0.4, 0.3), Color(0.35, 0.8, 1.0), Color(0.8, 0.7, 1.0)][i]
		fill.size = Vector2(0, 5)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fill)
		_bars[stat] = fill
	_info = UIKit.label("", 7, Color(0.88, 0.9, 1.0), 3)
	_info.position = Vector2(140, 224)
	_info.size = Vector2(250, 80)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page2.add_child(_info)
	# teams
	var tl := UIKit.label("YOUR TEAM", 9, Color(0.5, 0.8, 1.0), 3)
	tl.position = Vector2(410, 160)
	_page2.add_child(tl)
	_team_row = HBoxContainer.new()
	_team_row.position = Vector2(410, 174)
	_team_row.add_theme_constant_override("separation", 4)
	_page2.add_child(_team_row)
	var bl := UIKit.label("BOT TEAM", 9, Color(1, 0.5, 0.45), 3)
	bl.position = Vector2(410, 228)
	_page2.add_child(bl)
	_bot_row = HBoxContainer.new()
	_bot_row.position = Vector2(410, 242)
	_bot_row.add_theme_constant_override("separation", 4)
	_page2.add_child(_bot_row)
	_hint = UIKit.label("", 8, Color(1, 0.85, 0.4), 3)
	_hint.position = Vector2(140, 300)
	_page2.add_child(_hint)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 316)
	row.add_theme_constant_override("separation", 8)
	_page2.add_child(row)
	var rnd := UIKit.button("RANDOM", 10, Vector2(90, 28))
	rnd.pressed.connect(_random_team)
	row.add_child(rnd)
	var clr := UIKit.button("CLEAR", 10, Vector2(80, 28))
	clr.pressed.connect(func() -> void:
		picks.clear()
		_refresh_team())
	row.add_child(clr)
	var back := UIKit.button("BACK", 10, Vector2(80, 28))
	back.pressed.connect(func() -> void: _show_page(1))
	row.add_child(back)
	_fight = UIKit.button("FIGHT!", 13, Vector2(150, 28))
	_fight.name = "Fight"
	_fight.pressed.connect(start_match)
	row.add_child(_fight)
	_show_info("miles")


func _show_page(n: int) -> void:
	_page1.visible = n == 1
	_page2.visible = n == 2
	if n == 2:
		var t := _page2.get_node("Title") as Label
		t.text = "CHOOSE YOUR FIGHTER" if team_size() == 1 else "CHOOSE YOUR TEAM OF 3"
		if mode == "cpu":
			t.text = "CHOOSE THE BLUE TEAM (CPU)"
		bot_picks.clear()
		_refresh_team()
		(_cells[SpiderRoster.ORDER[0]] as Button).call_deferred("grab_focus")


func _show_info(key: String) -> void:
	var i := SpiderRoster.info(key)
	_preview.setup(String(i["sheet"]), 0.0)
	var data: Dictionary = SpriteDB.SHEETS[String(i["sheet"])]
	_preview.scale = Vector2.ONE * float(data["scale"]) * 2.2
	_preview.position = Vector2(75, 236)
	_preview.play("idle", true)
	_name.text = String(i["name"])
	(_bars["HP"] as ColorRect).size.x = 90.0 * clampf((float(i["hp"]) - 70.0) / 70.0, 0.1, 1.0)
	(_bars["POWER"] as ColorRect).size.x = 90.0 * clampf((float(i["power"]) - 0.8) / 0.4, 0.1, 1.0)
	(_bars["SPEED"] as ColorRect).size.x = 90.0 * clampf((float(i["speed"]) - 0.75) / 0.5, 0.1, 1.0)
	(_bars["DEFENSE"] as ColorRect).size.x = 90.0 * clampf((1.25 - float(i["defense"])) / 0.45, 0.1, 1.0)
	var sp: Array = i["specials"]
	_info.text = "%s\nPASSIVE  %s\nSPECIALS  %s / %s / %s%s" % [i["tagline"], SpiderRoster.PASSIVES.get(String(i["passive"]), ""),
		sp[0], sp[1], sp[2], "\n(1-bar special is a ranged energy blast)" if String(i["style"]) == "blast" else ""]


func _pick(key: String) -> void:
	if key in picks:
		picks.erase(key)
	elif picks.size() < team_size():
		picks.append(key)
	else:
		picks[picks.size() - 1] = key
	_refresh_team()


func _random_team() -> void:
	picks = SpiderRoster.random_team(_rng, team_size())
	_refresh_team()


func _refresh_team() -> void:
	if _team_row == null:
		return
	for c in _team_row.get_children():
		c.queue_free()
	for i in range(team_size()):
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(48, 48)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if i < picks.size():
			tr.texture = load(SpiderRoster.portrait_path(String(picks[i])))
		else:
			tr.modulate = Color(1, 1, 1, 0.15)
			tr.texture = load("res://assets/portraits/hero.png")
		_team_row.add_child(tr)
	for key in _cells:
		(_cells[key] as Button).modulate = Color(0.55, 0.85, 1.0) if key in picks else Color(1, 1, 1)
	_fight.disabled = picks.size() < team_size()
	_hint.text = "Pick %d more" % (team_size() - picks.size()) if picks.size() < team_size() else "Ready! The bot will now draft its team."


## Bot drafts from the full roster (no mirror of your exact team), then the match starts.
func start_match() -> void:
	if picks.size() < team_size():
		return
	bot_picks = SpiderRoster.random_team(_rng, team_size(), picks)
	for c in _bot_row.get_children():
		c.queue_free()
	for k in bot_picks:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(48, 48)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.flip_h = true
		tr.texture = load(SpiderRoster.portrait_path(String(k)))
		_bot_row.add_child(tr)
	_hint.text = "BOT TEAM: " + ", ".join(bot_picks.map(func(k: String) -> String: return String(SpiderRoster.info(k)["name"])))
	_fight.disabled = true
	Audio.play_sfx("boss_warn", 0.7)
	var cfg := {"mode": mode, "difficulty": difficulty, "stage": stage, "team1": picks.duplicate(), "team2": bot_picks.duplicate(),
		"cpu_vs_cpu": mode == "cpu"}
	GameState.versus_config = cfg
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		GameState.start_versus(cfg)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if _page2.visible:
			_show_page(1)
		else:
			GameState.goto_title()
