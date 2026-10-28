extends Control
## Campaign completion end card and scrolling credits.

var _scroll: VBoxContainer
var _speed: float = 22.0


func _ready() -> void:
	UIKit.full_rect(self)
	UIKit.backdrop(self, "res://assets/story/finale_victory.jpg", 0.55)
	_scroll = VBoxContainer.new()
	_scroll.position = Vector2(120, 360)
	_scroll.custom_minimum_size = Vector2(400, 0)
	_scroll.add_theme_constant_override("separation", 8)
	add_child(_scroll)
	var lines := [
		["CAMPAIGN COMPLETE", 22, Color(1, 0.85, 0.4)],
		["WEB-SLINGER: NIGHT PATROL", 14, Color(0.95, 0.25, 0.3)],
		["Thank you for playing!", 11, Color(1, 1, 1)],
		["", 8, Color.WHITE],
		["GAME DESIGN, CODE, ART & MUSIC", 10, Color(1, 0.75, 0.75)],
		["Original procedural art, animation, sound and music", 9, Color(0.9, 0.92, 1)],
		["created for this project (see tools/ in the repository)", 9, Color(0.9, 0.92, 1)],
		["", 8, Color.WHITE],
		["ENGINE", 10, Color(1, 0.75, 0.75)],
		["Godot Engine (MIT licence) - godotengine.org", 9, Color(0.9, 0.92, 1)],
		["", 8, Color.WHITE],
		["NOTICE", 10, Color(1, 0.75, 0.75)],
		["An unofficial, non-commercial fan project.", 9, Color(0.9, 0.92, 1)],
		["Spider-Man, Green Goblin and Mary Jane are Marvel characters.", 9, Color(0.9, 0.92, 1)],
		["Not affiliated with or endorsed by Marvel, Sony or any publisher.", 9, Color(0.9, 0.92, 1)],
		["", 8, Color.WHITE],
		["COMING IN LATER UPDATES", 10, Color(1, 0.75, 0.75)],
		["Scorpion  -  Doctor Octopus  -  Rhino  -  Kraven  -  Venom", 9, Color(0.9, 0.92, 1)],
	]
	for l in lines:
		var lab := UIKit.label(String(l[0]), int(l[1]), l[2], 4)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.custom_minimum_size = Vector2(400, 0)
		_scroll.add_child(lab)
	var hb := HBoxContainer.new()
	hb.position = Vector2(170, 320)
	hb.add_theme_constant_override("separation", 12)
	add_child(hb)
	var menu := UIKit.button("MAIN MENU", 10, Vector2(130, 26))
	menu.pressed.connect(GameState.goto_title)
	hb.add_child(menu)
	var sel := UIKit.button("REPLAY CHAPTERS", 10, Vector2(150, 26))
	sel.pressed.connect(GameState.goto_level_select)
	hb.add_child(sel)
	menu.call_deferred("grab_focus")
	Audio.play_music("title_theme")


func _process(delta: float) -> void:
	if _scroll.position.y > 30.0:
		_scroll.position.y -= _speed * delta
