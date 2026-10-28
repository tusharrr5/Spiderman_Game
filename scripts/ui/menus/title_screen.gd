extends Control
## Title screen: Continue / New Game, Level Select, Controls, Credits, Quit (desktop only).

var _controls: PanelContainer
var _confirm: ConfirmationDialog


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

	var vb := VBoxContainer.new()
	vb.position = Vector2(30, 140)
	vb.add_theme_constant_override("separation", 7)
	add_child(vb)
	var first: Button
	if GameState.has_any_progress():
		var cont := UIKit.button("CONTINUE  -  CHAPTER %d" % GameState.highest_unlocked)
		cont.pressed.connect(func() -> void: GameState.start_level(GameState.highest_unlocked))
		vb.add_child(cont)
		first = cont
	var newg := UIKit.button("NEW GAME" if not GameState.has_any_progress() else "PLAY FROM CHAPTER 1")
	newg.pressed.connect(func() -> void: GameState.start_level(1))
	vb.add_child(newg)
	if first == null:
		first = newg
	var sel := UIKit.button("LEVEL SELECT")
	sel.pressed.connect(GameState.goto_level_select)
	vb.add_child(sel)
	var ctr := UIKit.button("CONTROLS")
	ctr.pressed.connect(func() -> void: _controls.visible = true)
	vb.add_child(ctr)
	var cred := UIKit.button("CREDITS")
	cred.pressed.connect(GameState.goto_credits)
	vb.add_child(cred)
	if OS.get_name() != "Web" and OS.get_name() != "Android" and OS.get_name() != "iOS":
		var quit := UIKit.button("QUIT")
		quit.pressed.connect(func() -> void: get_tree().quit())
		vb.add_child(quit)

	var ver := UIKit.label("v1.0  |  Unofficial fan project  |  Built with Godot", 7, Color(0.7, 0.72, 0.85), 3)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(8, 344)
	add_child(ver)
	_build_controls_panel()
	first.call_deferred("grab_focus")
	Audio.play_music("title_theme")


func _build_controls_panel() -> void:
	_controls = PanelContainer.new()
	_controls.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL, UIKit.ACCENT, 8, 2))
	_controls.position = Vector2(110, 40)
	_controls.size = Vector2(420, 280)
	add_child(_controls)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_controls.add_child(vb)
	vb.add_child(UIKit.label("CONTROLS", 16, Color(1, 0.88, 0.45)))
	var rows := [
		["Move", "A / D  or  Arrow keys"], ["Jump / Super Jump", "SPACE  /  W + SPACE"], ["Climb walls & ceilings", "Run into walls, hold W"],
		["Punch combo / Kick", "J (x3)  /  H"], ["Web shot / Web swing", "K  (in the air near an anchor = swing)"],
		["Throw crate / Web slam", "L"], ["Dodge roll", "SHIFT"], ["Suit swap / Pause", "C  /  ESC"],
		["Touch", "On-screen pads appear in every chapter"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	vb.add_child(grid)
	for r in rows:
		grid.add_child(UIKit.label(r[0], 9, Color(1, 0.75, 0.75), 3))
		grid.add_child(UIKit.label(r[1], 9, Color(0.92, 0.94, 1.0), 3))
	var close := UIKit.button("CLOSE", 11, Vector2(120, 26))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: _controls.visible = false)
	vb.add_child(close)
	_controls.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and _controls.visible:
		_controls.visible = false
