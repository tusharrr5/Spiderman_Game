class_name DialogueBox
extends CanvasLayer
## Non-blocking in-level dialogue: portrait + speaker + typewriter text at the top of the screen.
## Lines queue up and auto-advance so gameplay never stops for story barks. Ignores mouse input.

signal queue_finished()

var _queue: Array = []
var _panel: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: Label
var _line_time: float = 0.0
var _line_duration: float = 0.0
var _chars: float = 0.0
var _busy: bool = false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.11, 0.88)
	sb.border_color = Color(0.85, 0.2, 0.25, 0.9)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(150, 296)
	_panel.custom_minimum_size = Vector2(340, 46)
	_panel.size = Vector2(340, 46)
	add_child(_panel)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 6)
	_panel.add_child(hb)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(38, 38)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_portrait)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 8)
	_name.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	vb.add_child(_name)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 8)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(286, 0)
	_text.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	vb.add_child(_text)
	_panel.visible = false


## lines: [[speaker_key, text], ...]
func queue_lines(lines: Array) -> void:
	for l in lines:
		_queue.append(l)
	if not _busy:
		_next()


func is_busy() -> bool:
	return _busy


func clear() -> void:
	_queue.clear()
	_busy = false
	_panel.visible = false


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		_panel.visible = false
		queue_finished.emit()
		return
	_busy = true
	var line: Array = _queue.pop_front()
	var speaker := String(line[0])
	var text := String(line[1])
	_name.text = StoryData.NAMES.get(speaker, speaker.to_upper())
	if speaker == "hint":
		_name.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	else:
		_name.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	var path := StoryData.portrait_path(speaker)
	_portrait.texture = load(path) if path != "" and ResourceLoader.exists(path) else null
	_portrait.visible = _portrait.texture != null
	_text.text = text
	_text.visible_characters = 0
	_chars = 0.0
	_line_time = 0.0
	_line_duration = clampf(1.6 + text.length() * 0.045, 2.4, 6.5)
	_panel.visible = true


func _process(delta: float) -> void:
	if not _busy:
		return
	_chars += delta * 55.0
	_text.visible_characters = int(_chars)
	_line_time += delta
	if _line_time >= _line_duration:
		_next()
