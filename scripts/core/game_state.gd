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

var highest_unlocked: int = 1
var completed: Dictionary = {}           # level number -> true
var best_times: Dictionary = {}          # level number -> seconds
var seen_controls_guide: bool = false
var dark_suit_unlocked: bool = false
var music_volume: float = 0.8
var sfx_volume: float = 0.9

# Current attempt
var current_level: int = 1
var checkpoint_index: int = -1           # -1 = level start
var checkpoint_objective: int = 0        # objective index active when the checkpoint was touched
var attempt_count: int = 0
var pending_story: String = ""           # story key to show in STORY_SCENE
var story_next: String = ""              # "level:N", "menu", "credits", "level_select"
var last_route: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


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


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "highest_unlocked", highest_unlocked)
	cfg.set_value("progress", "completed", completed.keys())
	cfg.set_value("progress", "best_times", best_times)
	cfg.set_value("progress", "dark_suit_unlocked", dark_suit_unlocked)
	cfg.set_value("settings", "seen_controls_guide", seen_controls_guide)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.save(save_path)


func reset_progress() -> void:
	highest_unlocked = 1
	completed = {}
	best_times = {}
	dark_suit_unlocked = false
	save_game()
	progress_changed.emit()


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
