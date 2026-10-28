extends Control
## Story panel player: illustrated panel + portrait + speaker + typewriter text.
## Advance with click/tap, SPACE, ENTER or J. SKIP jumps straight to gameplay.

var _panels: Array = []
var _i: int = -1
var _image: TextureRect
var _portrait: TextureRect
var _name: Label
var _text: Label
var _chars: float = 0.0
var _hint: Label
var _done: bool = false


func _ready() -> void:
	UIKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panels = StoryData.STORIES.get(GameState.pending_story, [])
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03)
	UIKit.full_rect(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_image = UIKit.backdrop(self, "res://assets/story/ch1_gang.jpg")
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.04, 0.1, 0.9), UIKit.ACCENT, 6, 2))
	box.position = Vector2(20, 262)
	box.size = Vector2(600, 86)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hb)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(70, 70)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_portrait)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	_name = UIKit.label("", 11, Color(1, 0.45, 0.45), 4)
	vb.add_child(_name)
	_text = UIKit.label("", 10, Color(0.95, 0.96, 1.0), 4)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(490, 50)
	vb.add_child(_text)
	_hint = UIKit.label("Click / SPACE to continue", 7, Color(0.7, 0.75, 0.9), 3)
	_hint.position = Vector2(500, 335)
	add_child(_hint)
	var skip := UIKit.button("SKIP >>", 9, Vector2(70, 22))
	skip.position = Vector2(560, 8)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(_finish)
	add_child(skip)
	if _panels.is_empty():
		_finish.call_deferred()
		return
	_advance()


func _advance() -> void:
	if _done:
		return
	if _i >= 0 and _text.visible_characters < _text.text.length() and _text.visible_characters >= 0:
		_text.visible_characters = -1
		return
	_i += 1
	if _i >= _panels.size():
		_finish()
		return
	var p: Dictionary = _panels[_i]
	var img := "res://assets/story/%s.jpg" % String(p.get("image", "ch1_gang"))
	if ResourceLoader.exists(img):
		_image.texture = load(img)
	var sp := String(p.get("speaker", ""))
	_name.text = StoryData.NAMES.get(sp, "")
	var path := StoryData.portrait_path(sp)
	_portrait.texture = load(path) if path != "" and ResourceLoader.exists(path) else null
	_portrait.visible = _portrait.texture != null
	_text.text = String(p.get("text", ""))
	_text.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0) if sp != "" else Color(0.85, 0.85, 0.7))
	_text.visible_characters = 0
	_chars = 0.0
	_image.modulate.a = 0.0
	create_tween().tween_property(_image, "modulate:a", 1.0, 0.35)


func _process(delta: float) -> void:
	if _text.visible_characters >= 0 and _text.visible_characters < _text.text.length():
		_chars += delta * 60.0
		_text.visible_characters = int(_chars)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or event.is_action_pressed("attack_punch"):
		_advance()
	elif event.is_action_pressed("pause_game"):
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	GameState.story_finished()
