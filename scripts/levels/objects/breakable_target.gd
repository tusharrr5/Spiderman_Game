class_name BreakableTarget
extends HurtboxComponent
## Something the hero punches, kicks or webs to break: cage locks, generators, switches.
## Uses the enemy hurtbox layer so the existing HitboxComponent / WebProjectile logic hits it unchanged.

signal broken(target: BreakableTarget)

@export var hits_required: int = 3
@export var texture_whole: String = "generator_on"
@export var texture_broken: String = "generator_off"
@export var label_text: String = "HIT IT!"
var target_id: String = ""
var is_broken: bool = false
var _hits: int = 0
var _sprite: Sprite2D
var _label: Label


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	owner_actor = self
	add_to_group("breakables")
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/props/%s.png" % texture_whole)
	_sprite.scale = Vector2(0.5, 0.5)
	add_child(_sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = _sprite.texture.get_size() * 0.5
	col.shape = shape
	add_child(col)
	_label = Label.new()
	_label.text = label_text
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(1, 0.95, 0.5))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.1))
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(80, 12)
	_label.position = Vector2(-40, -shape.size.y * 0.5 - 16)
	add_child(_label)


func _process(_delta: float) -> void:
	if not is_broken:
		_label.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006)


func receive_hit(_damage: int, _knockback: Vector2, _attack_type: String = "melee", _stun_duration: float = 0.25, _attacker: Node = null) -> bool:
	if is_broken:
		return false
	_hits += 1
	Audio.play_sfx("cage_break", 0.6)
	Fx.burst(get_parent(), global_position, Color(1, 0.9, 0.5), 8, 90.0, 160.0, 0.3)
	_sprite.position = Vector2(randf_range(-2, 2), 0)
	_label.text = "%d / %d" % [_hits, hits_required]
	if _hits >= hits_required:
		is_broken = true
		_sprite.texture = load("res://assets/props/%s.png" % texture_broken)
		_sprite.position = Vector2.ZERO
		_label.text = ""
		Fx.shake(3.0, 0.2)
		broken.emit(self)
	return true


func reset_target() -> void:
	is_broken = false
	_hits = 0
	_sprite.texture = load("res://assets/props/%s.png" % texture_whole)
	_label.text = label_text
