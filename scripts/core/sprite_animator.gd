class_name SpriteAnimator
extends Sprite2D
## Plays named animations from a generated horizontal sprite strip described in SpriteDB.
## Sheets are drawn at 2x resolution and displayed at scale 0.5 so they map 1:1 onto a 1280x720 window.

signal animation_finished(anim_name: String)

const DISPLAY_SCALE: float = 0.5

var sheet_key: String = ""
var anim_name: String = ""
var _anims: Dictionary = {}
var _frame_in_anim: int = 0
var _time: float = 0.0
var _finished: bool = false
var speed_scale: float = 1.0


## feet_y: local y (in the parent's units) where the character's feet should rest.
func setup(key: String, feet_y: float = 0.0) -> void:
	var info: Dictionary = SpriteDB.SHEETS[key]
	sheet_key = key
	texture = load(info["path"])
	hframes = int(info["count"])
	vframes = 1
	_anims = info["anims"]
	scale = Vector2(DISPLAY_SCALE, DISPLAY_SCALE)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var frame_px: float = float(info["frame"])
	# generated frames rest the feet 6px above the frame bottom
	position.y = feet_y - (frame_px * 0.5 - 6.0) * DISPLAY_SCALE
	if anim_name == "" or not _anims.has(anim_name):
		play(_anims.keys()[0], true)
	else:
		play(anim_name, true)


## Swap to another sheet with the same animation layout (e.g. suit palettes) keeping the current frame.
func swap_sheet(key: String) -> void:
	var info: Dictionary = SpriteDB.SHEETS[key]
	sheet_key = key
	texture = load(info["path"])
	_anims = info["anims"]


func has_anim(name: String) -> bool:
	return _anims.has(name)


func play(name: String, restart: bool = false) -> void:
	if not _anims.has(name):
		return
	if name == anim_name and not restart:
		return
	anim_name = name
	_frame_in_anim = 0
	_time = 0.0
	_finished = false
	_apply_frame()


func is_finished() -> bool:
	return _finished


func _process(delta: float) -> void:
	if anim_name == "" or _finished:
		return
	var a: Array = _anims[anim_name]
	var fps: float = float(a[2]) * speed_scale
	if fps <= 0.0:
		return
	_time += delta
	var step: float = 1.0 / fps
	while _time >= step:
		_time -= step
		_frame_in_anim += 1
		if _frame_in_anim >= int(a[1]):
			if bool(a[3]):
				_frame_in_anim = 0
			else:
				_frame_in_anim = int(a[1]) - 1
				_finished = true
				animation_finished.emit(anim_name)
				break
	_apply_frame()


func _apply_frame() -> void:
	var a: Array = _anims[anim_name]
	frame = clampi(int(a[0]) + _frame_in_anim, 0, hframes - 1)
