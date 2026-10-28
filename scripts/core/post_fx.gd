class_name PostFX
extends CanvasLayer
## Full-screen colour grade / bloom / vignette over the game world. The HUD sits on a higher layer and is
## not graded. Per-theme looks keep each chapter's mood; quality "low" disables the pass for weak devices.

const SHADER: Shader = preload("res://assets/shaders/post_grade.gdshader")

const LOOKS: Dictionary = {
	"street_dusk": {"shadow_tint": Vector3(0.03, 0.02, 0.07), "highlight_tint": Vector3(1.08, 0.98, 0.9), "saturation": 1.12},
	"rooftop_sunset": {"shadow_tint": Vector3(0.04, 0.01, 0.05), "highlight_tint": Vector3(1.1, 0.97, 0.86), "saturation": 1.15},
	"night_industrial": {"shadow_tint": Vector3(0.0, 0.03, 0.07), "highlight_tint": Vector3(0.98, 1.02, 1.04), "saturation": 1.05},
	"goblin_facility": {"shadow_tint": Vector3(0.0, 0.04, 0.03), "highlight_tint": Vector3(0.98, 1.05, 0.96), "saturation": 1.08},
	"storm_finale": {"shadow_tint": Vector3(0.02, 0.02, 0.08), "highlight_tint": Vector3(1.0, 0.98, 1.06), "saturation": 1.0},
}

var rect: ColorRect
var mat: ShaderMaterial
var _letterbox: float = 0.0
var _letterbox_target: float = 0.0


func _init() -> void:
	layer = 5
	name = "PostFX"
	add_to_group("post_fx")


func _ready() -> void:
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)
	visible = GameState.fx_quality != "low"


func apply_theme(theme: String) -> void:
	var look: Dictionary = LOOKS.get(theme, {})
	for k in look:
		mat.set_shader_parameter(k, look[k])


func set_letterbox(on: bool) -> void:
	_letterbox_target = 1.0 if on else 0.0


## Cinematic bars for a special move, removed automatically.
func pulse_letterbox(duration: float) -> void:
	set_letterbox(true)
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void: set_letterbox(false))


func _process(delta: float) -> void:
	if not is_equal_approx(_letterbox, _letterbox_target):
		_letterbox = move_toward(_letterbox, _letterbox_target, delta * 4.0)
		mat.set_shader_parameter("letterbox", _letterbox)
