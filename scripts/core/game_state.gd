extends Node
## Autoload "GameState": campaign progression, persistent saves, checkpoints and scene routing.
## Saves live in user://savegame.cfg so progress survives closing the game (desktop, web and Android).

signal progress_changed()

## Tests point this at a scratch file so they never touch the player's real save.
var save_path: String = "user://savegame.cfg"
## Tests disable scene routing to inspect a chapter after it completes or fails.
var routing_enabled: bool = true
const TITLE_SCENE: String = "res://scenes/menus/title_screen.tscn"
const LEVEL_SELECT_SCENE: String = "res://scenes/menus/level_select.tscn"
const STORY_SCENE: String = "res://scenes/menus/story_scene.tscn"
const CAMPAIGN_LEVEL_SCENE: String = "res://scenes/levels/campaign_level.tscn"
const CREDITS_SCENE: String = "res://scenes/menus/credits.tscn"
const ARENA_HUB_SCENE: String = "res://scenes/menus/arena_hub.tscn"
const SHOP_SCENE: String = "res://scenes/menus/shop.tscn"
const ARENA_SCENE: String = "res://scenes/levels/arena_level.tscn"
const VERSUS_SETUP_SCENE: String = "res://scenes/menus/versus_setup.tscn"
const VERSUS_SCENE: String = "res://scenes/levels/versus_level.tscn"

var highest_unlocked: int = 1
var completed: Dictionary = {}           # level number -> true
var best_times: Dictionary = {}          # level number -> seconds
var seen_controls_guide: bool = false
var dark_suit_unlocked: bool = false
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var fx_quality: String = "high"          # "high" = post-processing on, "low" = off (weak devices)

# ---- replay economy: tokens, upgrades, suits, ranks, arena records, daily challenge
## upgrade key -> [display name, description, base cost]
const UPGRADES: Dictionary = {
	"vitality": ["VITALITY", "+12 max health per level", 120],
	"strength": ["STRENGTH", "+8% attack damage per level", 150],
	"focus": ["FOCUS", "+15% power meter gain per level", 130],
	"reflex": ["REFLEX", "Wider parry window per level", 160],
}
const UPGRADE_MAX: int = 5
## suit key -> [display name, token cost]
const SUITS: Dictionary = {
	"classic": ["CLASSIC", 0],
	"dark": ["SYMBIOTE BLACK", 0],
	"midnight": ["MIDNIGHT GOLD", 600],
	"crimson": ["CRIMSON STEALTH", 900],
	"arctic": ["ARCTIC TECH", 1200],
}
var tokens: int = 0
var upgrades: Dictionary = {}
var suits_owned: Array = ["classic"]
var suit_equipped: String = "classic"
var chapter_rank: Dictionary = {}         # level -> best rank letter
var chapter_stars: Dictionary = {}        # level -> best stars (0-3)
var best_scores: Dictionary = {}          # level -> best score
var arena_best: Dictionary = {}           # "gauntlet" -> highest tier cleared, "survival" -> best wave, "survival_score"
var daily_done: String = ""               # date of the last cleared daily challenge
var daily_streak: int = 0

# Current attempt
var current_level: int = 1
var checkpoint_index: int = -1           # -1 = level start
var checkpoint_objective: int = 0        # objective index active when the checkpoint was touched
var attempt_count: int = 0
var pending_story: String = ""           # story key to show in STORY_SCENE
var story_next: String = ""              # "level:N", "menu", "credits", "level_select"
var last_route: String = ""
var arena_mode: String = "gauntlet"      # gauntlet | survival | daily
## Versus match setup: {mode, difficulty, stage, team1: [keys], team2: [keys], cpu_vs_cpu}
var versus_config: Dictionary = {}
## Versus records: wins, losses, streak, best_streak, wins_<difficulty>
var versus_stats: Dictionary = {}
var char_wins: Dictionary = {}            # roster key -> versus wins with that fighter
var arena_tier: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_display_title()
	load_game()


## config/name keeps its old value because it decides the desktop user:// (save) folder; show the real title instead.
func _set_display_title() -> void:
	const TITLE := "Web-Slinger: Night Patrol"
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.title = '%s'" % TITLE)
	elif DisplayServer.get_name() != "headless":
		get_window().title = TITLE


# ------------------------------------------------------------------ persistence
func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	highest_unlocked = clampi(int(cfg.get_value("progress", "highest_unlocked", 1)), 1, LevelRegistry.PLAYABLE_LEVELS)
	completed = {}
	for n in cfg.get_value("progress", "completed", []):
		completed[int(n)] = true
	best_times = cfg.get_value("progress", "best_times", {})
	seen_controls_guide = bool(cfg.get_value("settings", "seen_controls_guide", false))
	dark_suit_unlocked = bool(cfg.get_value("progress", "dark_suit_unlocked", false))
	music_volume = float(cfg.get_value("settings", "music_volume", 0.8))
	sfx_volume = float(cfg.get_value("settings", "sfx_volume", 0.9))
	fx_quality = String(cfg.get_value("settings", "fx_quality", "high"))
	tokens = int(cfg.get_value("economy", "tokens", 0))
	upgrades = cfg.get_value("economy", "upgrades", {})
	suits_owned = cfg.get_value("economy", "suits_owned", ["classic"])
	suit_equipped = String(cfg.get_value("economy", "suit_equipped", "classic"))
	chapter_rank = cfg.get_value("records", "chapter_rank", {})
	chapter_stars = cfg.get_value("records", "chapter_stars", {})
	best_scores = cfg.get_value("records", "best_scores", {})
	arena_best = cfg.get_value("records", "arena_best", {})
	daily_done = String(cfg.get_value("records", "daily_done", ""))
	daily_streak = int(cfg.get_value("records", "daily_streak", 0))
	versus_stats = cfg.get_value("records", "versus_stats", {})
	char_wins = cfg.get_value("records", "char_wins", {})


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "highest_unlocked", highest_unlocked)
	cfg.set_value("progress", "completed", completed.keys())
	cfg.set_value("progress", "best_times", best_times)
	cfg.set_value("progress", "dark_suit_unlocked", dark_suit_unlocked)
	cfg.set_value("settings", "seen_controls_guide", seen_controls_guide)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "fx_quality", fx_quality)
	cfg.set_value("economy", "tokens", tokens)
	cfg.set_value("economy", "upgrades", upgrades)
	cfg.set_value("economy", "suits_owned", suits_owned)
	cfg.set_value("economy", "suit_equipped", suit_equipped)
	cfg.set_value("records", "chapter_rank", chapter_rank)
	cfg.set_value("records", "chapter_stars", chapter_stars)
	cfg.set_value("records", "best_scores", best_scores)
	cfg.set_value("records", "arena_best", arena_best)
	cfg.set_value("records", "daily_done", daily_done)
	cfg.set_value("records", "daily_streak", daily_streak)
	cfg.set_value("records", "versus_stats", versus_stats)
	cfg.set_value("records", "char_wins", char_wins)
	cfg.save(save_path)


func reset_progress() -> void:
	highest_unlocked = 1
	completed = {}
	best_times = {}
	dark_suit_unlocked = false
	tokens = 0
	upgrades = {}
	suits_owned = ["classic"]
	suit_equipped = "classic"
	chapter_rank = {}
	chapter_stars = {}
	best_scores = {}
	arena_best = {}
	daily_done = ""
	daily_streak = 0
	versus_stats = {}
	char_wins = {}
	save_game()
	progress_changed.emit()


# ------------------------------------------------------------------ economy
func get_upgrade(key: String) -> int:
	return int(upgrades.get(key, 0))


func upgrade_cost(key: String) -> int:
	return int(UPGRADES[key][2]) * (get_upgrade(key) + 1)


func buy_upgrade(key: String) -> bool:
	if get_upgrade(key) >= UPGRADE_MAX or tokens < upgrade_cost(key):
		return false
	tokens -= upgrade_cost(key)
	upgrades[key] = get_upgrade(key) + 1
	save_game()
	progress_changed.emit()
	return true


func owns_suit(key: String) -> bool:
	return key in suits_owned or (key == "dark" and dark_suit_unlocked)


func buy_suit(key: String) -> bool:
	if owns_suit(key) or tokens < int(SUITS[key][1]):
		return false
	tokens -= int(SUITS[key][1])
	suits_owned.append(key)
	save_game()
	progress_changed.emit()
	return true


func equip_suit(key: String) -> void:
	if owns_suit(key):
		suit_equipped = key
		save_game()
		progress_changed.emit()


func add_tokens(n: int) -> void:
	tokens = maxi(0, tokens + n)
	save_game()
	progress_changed.emit()


## Records a chapter result; returns true when it beat the previous best score.
func record_chapter_result(n: int, score: int, rank: String, stars: int) -> bool:
	var better := score > int(best_scores.get(n, -1))
	if better:
		best_scores[n] = score
	if _rank_value(rank) > _rank_value(String(chapter_rank.get(n, ""))):
		chapter_rank[n] = rank
	chapter_stars[n] = maxi(stars, int(chapter_stars.get(n, 0)))
	save_game()
	return better


func _rank_value(r: String) -> int:
	return ["", "D", "C", "B", "A", "S"].find(r)


func total_stars() -> int:
	var t := 0
	for k in chapter_stars:
		t += int(chapter_stars[k])
	return t


func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


func is_unlocked(n: int) -> bool:
	return n >= 1 and n <= LevelRegistry.PLAYABLE_LEVELS and n <= highest_unlocked


func is_completed(n: int) -> bool:
	return completed.has(n)


func has_any_progress() -> bool:
	return highest_unlocked > 1 or not completed.is_empty()


## Marks a level complete, unlocks the next one and persists immediately.
func complete_level(n: int, time_seconds: float = 0.0) -> void:
	completed[n] = true
	if n + 1 <= LevelRegistry.PLAYABLE_LEVELS:
		highest_unlocked = maxi(highest_unlocked, n + 1)
	if n >= 3:
		dark_suit_unlocked = true
	if time_seconds > 0.0 and (not best_times.has(n) or time_seconds < float(best_times[n])):
		best_times[n] = time_seconds
	save_game()
	progress_changed.emit()


# ------------------------------------------------------------------ routing
func _change_scene(path: String) -> void:
	last_route = path
	if not routing_enabled:
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().call_deferred("change_scene_to_file", path)


func goto_title() -> void:
	_change_scene(TITLE_SCENE)


func goto_level_select() -> void:
	_change_scene(LEVEL_SELECT_SCENE)


func goto_arena_hub() -> void:
	_change_scene(ARENA_HUB_SCENE)


func goto_shop() -> void:
	_change_scene(SHOP_SCENE)


func is_arena_unlocked() -> bool:
	return is_completed(1)


func goto_versus_setup() -> void:
	_change_scene(VERSUS_SETUP_SCENE)


func start_versus(cfg: Dictionary) -> void:
	versus_config = cfg.duplicate(true)
	_change_scene(VERSUS_SCENE)


func record_versus(won: bool, difficulty: String, team: Array, _team_mode: bool) -> void:
	var v := versus_stats
	if won:
		v["wins"] = int(v.get("wins", 0)) + 1
		v["streak"] = int(v.get("streak", 0)) + 1
		v["best_streak"] = maxi(int(v.get("best_streak", 0)), int(v["streak"]))
		v["wins_" + difficulty] = int(v.get("wins_" + difficulty, 0)) + 1
		for k in team:
			char_wins[k] = int(char_wins.get(k, 0)) + 1
	else:
		v["losses"] = int(v.get("losses", 0)) + 1
		v["streak"] = 0
	save_game()


func start_arena(p_mode: String, p_tier: int = 1) -> void:
	arena_mode = p_mode
	arena_tier = maxi(1, p_tier)
	_change_scene(ARENA_SCENE)


func goto_credits() -> void:
	_change_scene(CREDITS_SCENE)


## Starts a chapter from the beginning, showing its intro story first.
func start_level(n: int, show_intro: bool = true) -> void:
	if not is_unlocked(n):
		return
	current_level = n
	checkpoint_index = -1
	checkpoint_objective = 0
	attempt_count = 0
	var data: Dictionary = LevelRegistry.get_level(n)
	if show_intro and data.has("intro_story"):
		show_story(String(data["intro_story"]), "level:%d" % n)
	else:
		_change_scene(CAMPAIGN_LEVEL_SCENE)


## Retries the CURRENT level (never resets to Level 1), resuming from the last checkpoint reached.
func retry_level(from_checkpoint: bool = true) -> void:
	if not from_checkpoint:
		checkpoint_index = -1
		checkpoint_objective = 0
	attempt_count += 1
	_change_scene(CAMPAIGN_LEVEL_SCENE)


func reach_checkpoint(index: int) -> void:
	checkpoint_index = maxi(checkpoint_index, index)


func finish_level(n: int, time_seconds: float) -> void:
	complete_level(n, time_seconds)
	var data: Dictionary = LevelRegistry.get_level(n)
	var next := "level_select"
	if n < LevelRegistry.PLAYABLE_LEVELS:
		next = "level:%d" % (n + 1)
	else:
		next = "credits"
	if data.has("outro_story"):
		show_story(String(data["outro_story"]), next)
	else:
		_follow(next)


func show_story(key: String, next: String) -> void:
	pending_story = key
	story_next = next
	_change_scene(STORY_SCENE)


## Called by the story scene once its panels finish or are skipped.
func story_finished() -> void:
	var next := story_next
	story_next = ""
	_follow(next)


func _follow(next: String) -> void:
	if next.begins_with("level:"):
		var n := int(next.substr(6))
		if pending_story != "" and pending_story == String(LevelRegistry.get_level(n).get("intro_story", "")):
			# intro already shown -> straight into gameplay
			current_level = n
			checkpoint_index = -1
			checkpoint_objective = 0
			attempt_count = 0
			pending_story = ""
			_change_scene(CAMPAIGN_LEVEL_SCENE)
		else:
			pending_story = ""
			start_level(n, true)
	elif next == "credits":
		pending_story = ""
		goto_credits()
	elif next == "menu":
		pending_story = ""
		goto_title()
	else:
		pending_story = ""
		goto_level_select()
