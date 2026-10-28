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

# ---- versus progression: pre-fight boosts, fighter levels, daily login reward, challenges
## boost key -> [name, effect, token price, colour]
const BOOSTS: Dictionary = {
	"attack": ["ATTACK BOOST", "+20% attack", 90, Color(1.0, 0.4, 0.3)],
	"defense": ["DEFENSE BOOST", "-20% damage taken", 90, Color(0.5, 0.75, 1.0)],
	"power": ["POWER BOOST", "+1 power bar at the start, +25% power gain", 110, Color(0.35, 0.85, 1.0)],
	"crit": ["CRIT BOOST", "+15% critical hit chance", 100, Color(1.0, 0.85, 0.3)],
	"health": ["HEALTH BOOST", "+20% max health", 100, Color(0.4, 1.0, 0.5)],
}
const MAX_BOOSTS_PER_FIGHT: int = 2
const FIGHTER_MAX_LEVEL: int = 10
const XP_PER_LEVEL: int = 100
## [id, title, counter, target, token reward]
const CHALLENGES: Array = [
	["win1", "First blood: win a versus match", "vs_wins", 1, 50],
	["win10", "Contender: win 10 versus matches", "vs_wins", 10, 200],
	["win50", "Champion: win 50 versus matches", "vs_wins", 50, 800],
	["team5", "Squad goals: win 5 matches in 3 VS 3", "team_wins", 5, 250],
	["hard1", "Bot breaker: beat MORE DIFFICULT", "wins_more_difficult", 1, 300],
	["hard10", "Unstoppable: beat MORE DIFFICULT 10 times", "wins_more_difficult", 10, 1000],
	["parry25", "Spider-sense: parry 25 attacks", "parries", 25, 150],
	["parry100", "Untouchable: parry 100 attacks", "parries", 100, 500],
	["combo20", "Five-hit hero: land 20 five-hit combos", "five_hit", 20, 200],
	["sp3_10", "Maximum power: land 10 level-3 specials", "sp3", 10, 250],
	["debuff50", "Dirty tricks: inflict 50 debuffs", "debuffs", 50, 200],
	["perfect1", "Flawless: win a round without taking damage", "perfects", 1, 200],
	["streak5", "On fire: reach a 5-win streak", "best_streak", 5, 300],
	["roster10", "Multiverse: win with 10 different fighters", "fighters_won", 10, 400],
	["level10", "Max rank: get any fighter to level 10", "max_level", 10, 500],
]
var boosts: Dictionary = {"attack": 1, "defense": 1}   # boost key -> count (two starter boosts)
var fighter_xp: Dictionary = {}           # roster key -> xp
var login_day: String = ""
var login_streak: int = 0
var challenge_progress: Dictionary = {}   # counter -> value
var challenges_claimed: Array = []
## Filled by record_versus for the results screen: xp, level-ups, boost drop, finished challenges
var last_versus_rewards: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	KeyBindings.load_and_apply()
	_set_display_title()
	load_game()


## config/name keeps its old value because it decides the desktop user:// (save) folder; show the real title instead.
## Waits a frame because the engine applies config/name to the window (and the web page title) after autoloads start.
func _set_display_title() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Web-Slinger: Night Patrol")


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
	boosts = cfg.get_value("versus", "boosts", {"attack": 1, "defense": 1})
	fighter_xp = cfg.get_value("versus", "fighter_xp", {})
	login_day = String(cfg.get_value("versus", "login_day", ""))
	login_streak = int(cfg.get_value("versus", "login_streak", 0))
	challenge_progress = cfg.get_value("versus", "challenge_progress", {})
	challenges_claimed = cfg.get_value("versus", "challenges_claimed", [])


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
	cfg.set_value("versus", "boosts", boosts)
	cfg.set_value("versus", "fighter_xp", fighter_xp)
	cfg.set_value("versus", "login_day", login_day)
	cfg.set_value("versus", "login_streak", login_streak)
	cfg.set_value("versus", "challenge_progress", challenge_progress)
	cfg.set_value("versus", "challenges_claimed", challenges_claimed)
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
	boosts = {"attack": 1, "defense": 1}
	fighter_xp = {}
	login_day = ""
	login_streak = 0
	challenge_progress = {}
	challenges_claimed = []
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


## The shop's BACK button returns to the screen that opened it.
var shop_return: String = "arena"


func goto_shop(from: String = "arena") -> void:
	shop_return = from
	_change_scene(SHOP_SCENE)


func is_arena_unlocked() -> bool:
	return is_completed(1)


func goto_versus_setup() -> void:
	_change_scene(VERSUS_SETUP_SCENE)


func start_versus(cfg: Dictionary) -> void:
	versus_config = cfg.duplicate(true)
	_change_scene(VERSUS_SCENE)


func record_versus(won: bool, difficulty: String, team: Array, team_mode: bool, fight_stats: Dictionary = {}) -> void:
	var v := versus_stats
	var rewards := {"xp": 0, "levels": [], "boost": "", "challenges": []}
	if won:
		v["wins"] = int(v.get("wins", 0)) + 1
		v["streak"] = int(v.get("streak", 0)) + 1
		v["best_streak"] = maxi(int(v.get("best_streak", 0)), int(v["streak"]))
		v["wins_" + difficulty] = int(v.get("wins_" + difficulty, 0)) + 1
		for k in team:
			char_wins[k] = int(char_wins.get(k, 0)) + 1
		bump("vs_wins")
		if team_mode:
			bump("team_wins")
		if difficulty == "more_difficult":
			bump("wins_more_difficult")
		# boost drop: more likely against a harder bot
		var drop_p: float = {"easy": 0.25, "moderate": 0.4, "difficult": 0.6, "more_difficult": 0.85}.get(difficulty, 0.4)
		if randf() < drop_p:
			var keys := BOOSTS.keys()
			rewards["boost"] = keys[randi() % keys.size()]
			add_boost(String(rewards["boost"]))
	else:
		v["losses"] = int(v.get("losses", 0)) + 1
		v["streak"] = 0
	for c in ["parries", "five_hit", "sp3", "debuffs", "perfects"]:
		if fight_stats.has(c):
			bump(c, int(fight_stats[c]))
	var xp := int(round((60.0 if won else 25.0) * float({"easy": 0.6, "moderate": 1.0, "difficult": 1.4, "more_difficult": 1.8}.get(difficulty, 1.0))))
	rewards["xp"] = xp
	for k in team:
		var before := fighter_level(String(k))
		fighter_xp[k] = int(fighter_xp.get(k, 0)) + xp
		if fighter_level(String(k)) > before:
			rewards["levels"].append([k, fighter_level(String(k))])
	rewards["challenges"] = check_challenges()
	last_versus_rewards = rewards
	save_game()


# ------------------------------------------------------------------ versus progression
func fighter_level(key: String) -> int:
	return mini(FIGHTER_MAX_LEVEL, 1 + int(fighter_xp.get(key, 0)) / XP_PER_LEVEL)


## Fraction of the way to the next level (1.0 at max level).
func fighter_level_progress(key: String) -> float:
	if fighter_level(key) >= FIGHTER_MAX_LEVEL:
		return 1.0
	return float(int(fighter_xp.get(key, 0)) % XP_PER_LEVEL) / float(XP_PER_LEVEL)


## +2% health and attack per level above 1.
func fighter_level_bonus(key: String) -> float:
	return 0.02 * (fighter_level(key) - 1)


func add_boost(key: String, n: int = 1) -> void:
	boosts[key] = int(boosts.get(key, 0)) + n


func use_boost(key: String) -> bool:
	if int(boosts.get(key, 0)) <= 0:
		return false
	boosts[key] = int(boosts[key]) - 1
	return true


func buy_boost(key: String) -> bool:
	var price := int(BOOSTS[key][2])
	if tokens < price:
		return false
	tokens -= price
	add_boost(key)
	save_game()
	return true


## Daily login reward: tokens grow with the streak (7-day cycle) and days 3, 5 and 7 add boosts.
## Returns {} when today's reward was already claimed.
func claim_daily_login() -> Dictionary:
	var today := today_key()
	if login_day == today:
		return {}
	var yesterday := Time.get_date_string_from_unix_time(Time.get_unix_time_from_system() - 86400.0)
	login_streak = login_streak + 1 if login_day == yesterday else 1
	login_day = today
	var day := (login_streak - 1) % 7 + 1
	var reward := {"day": day, "streak": login_streak, "tokens": 40 + 20 * day, "boosts": []}
	tokens += int(reward["tokens"])
	if day in [3, 5, 7]:
		var keys := BOOSTS.keys()
		for _i in range(2 if day == 7 else 1):
			var b: String = keys[randi() % keys.size()]
			add_boost(b)
			reward["boosts"].append(b)
	save_game()
	return reward


func bump(counter: String, n: int = 1) -> void:
	challenge_progress[counter] = int(challenge_progress.get(counter, 0)) + n


func challenge_value(counter: String) -> int:
	match counter:
		"best_streak":
			return int(versus_stats.get("best_streak", 0))
		"fighters_won":
			return char_wins.size()
		"max_level":
			var best := 1
			for k in fighter_xp:
				best = maxi(best, fighter_level(String(k)))
			return best
	return int(challenge_progress.get(counter, 0))


## Pays out every newly completed challenge; returns [[title, tokens], ...].
func check_challenges() -> Array:
	var done: Array = []
	for c in CHALLENGES:
		if c[0] in challenges_claimed:
			continue
		if challenge_value(String(c[2])) >= int(c[3]):
			challenges_claimed.append(c[0])
			tokens += int(c[4])
			done.append([c[1], c[4]])
	return done


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
