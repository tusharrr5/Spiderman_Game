extends Control
## Level select: chapters 1-5 (locked / available / complete with best time) and the planned
## chapters 6-20 shown as "coming in a later update" - never presented as playable.


func _ready() -> void:
	UIKit.full_rect(self)
	UIKit.backdrop(self, "res://assets/ui/title_bg.jpg", 0.55)
	var title := UIKit.label("SELECT CHAPTER", 20, Color(1, 0.9, 0.5), 7)
	title.position = Vector2(20, 10)
	add_child(title)
	var back := UIKit.button("< BACK", 10, Vector2(80, 24))
	back.position = Vector2(540, 12)
	back.pressed.connect(GameState.goto_title)
	add_child(back)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(14, 46)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	var first: Button = null
	for n in range(1, LevelRegistry.TOTAL_PLANNED_LEVELS + 1):
		var b := _card(n)
		grid.add_child(b)
		if first == null and not b.disabled:
			first = b
	var reset := UIKit.button("RESET PROGRESS", 8, Vector2(110, 20))
	reset.position = Vector2(516, 334)
	add_child(reset)
	var confirm := ConfirmationDialog.new()
	confirm.dialog_text = "Erase all saved chapter progress?"
	confirm.confirmed.connect(func() -> void:
		GameState.reset_progress()
		get_tree().reload_current_scene())
	add_child(confirm)
	reset.pressed.connect(func() -> void: confirm.popup_centered())
	if first != null:
		first.call_deferred("grab_focus")
	Audio.play_music("title_theme")


func _card(n: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(118, 66)
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UIKit.style_button(b, 8)
	if n <= LevelRegistry.PLAYABLE_LEVELS:
		var d := LevelRegistry.get_level(n)
		var status := "LOCKED"
		if GameState.is_completed(n):
			var bt: String = ""
			if GameState.best_times.has(n):
				bt = "  " + UIKit.format_time(float(GameState.best_times[n]))
			status = "* COMPLETE" + bt
		elif GameState.is_unlocked(n):
			status = "> PLAY"
		b.text = "CHAPTER %d\n%s\n%s" % [n, _wrap(String(d["title"])), status]
		b.disabled = not GameState.is_unlocked(n)
		b.pressed.connect(func() -> void: GameState.start_level(n))
	else:
		var arc := LevelRegistry.future_entry(n)
		b.text = "LEVEL %d\n%s\nCOMING SOON" % [n, String(arc.get("arc", ""))]
		b.tooltip_text = String(arc.get("blurb", ""))
		b.disabled = true
	return b


func _wrap(t: String) -> String:
	if t.length() <= 18:
		return t
	var cut := t.rfind(" ", 18)
	return t.substr(0, cut) + "\n" + t.substr(cut + 1) if cut > 0 else t


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		GameState.goto_title()
