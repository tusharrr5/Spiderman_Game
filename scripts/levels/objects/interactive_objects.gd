class_name InteractiveZone
extends Area2D
## Player-detecting zone used for checkpoints, pickups, exits, dialogue/event triggers and hazards.
## kind: "checkpoint" | "pickup" | "exit" | "trigger" | "shock" | "kill"

signal activated(zone: InteractiveZone)

var kind: String = "trigger"
var zone_id: String = ""
var index: int = 0
var once: bool = true
var payload: Dictionary = {}
var size: Vector2 = Vector2(24, 48)
var active: bool = true
var _fired: bool = false
var _sprite: Sprite2D
var _timer: float = 0.0
var _shock_on: bool = true
var _overlapping: Array[PlayerController] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	match kind:
		"checkpoint":
			_sprite = _make_sprite("checkpoint_off", Vector2(0, size.y * 0.5 - 16))
		"pickup":
			_sprite = _make_sprite("health_pickup", Vector2.ZERO)
		"exit":
			_sprite = _make_sprite(String(payload.get("sprite", "exit_door")), Vector2(0, size.y * 0.5 - 25))
		"shock":
			_build_shock_visual()
	if kind == "shock":
		_timer = float(payload.get("offset", 0.0))


func _make_sprite(tex: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/props/%s.png" % tex)
	s.scale = Vector2(0.5, 0.5)
	s.position = pos
	add_child(s)
	return s


func _build_shock_visual() -> void:
	var n := int(ceil(size.x / 32.0))
	for i in range(n):
		var s := Sprite2D.new()
		s.texture = load("res://assets/props/shock_on.png")
		s.scale = Vector2(0.5, 0.5)
		s.position = Vector2(-size.x * 0.5 + 16.0 + i * 32.0, size.y * 0.5 - 4.0)
		s.name = "Shock%d" % i
		add_child(s)


func _process(delta: float) -> void:
	if kind == "pickup" and _sprite != null:
		_sprite.position.y = sin(Time.get_ticks_msec() * 0.005) * 2.0
	if kind == "shock":
		var period_on := float(payload.get("on", 1.4))
		var period_off := float(payload.get("off", 1.4))
		_timer += delta
		var cycle := fmod(_timer, period_on + period_off)
		var now_on := cycle < period_on
		if now_on != _shock_on:
			_shock_on = now_on
			for c in get_children():
				if c is Sprite2D:
					(c as Sprite2D).texture = load("res://assets/props/%s.png" % ("shock_on" if now_on else "shock_off"))
			if now_on:
				Audio.play_sfx("shock", 0.35)
		if _shock_on:
			for p in _overlapping:
				if is_instance_valid(p):
					p.apply_combat_hit(int(payload.get("damage", 14)), Vector2(0, -230), "shock")


func is_shock_on() -> bool:
	return _shock_on


func _on_body_entered(body: Node2D) -> void:
	if not (body is PlayerController) or not active:
		return
	var p := body as PlayerController
	match kind:
		"shock":
			_overlapping.append(p)
			return
		"kill":
			p.health_component.take_damage(999, Vector2.ZERO, "pitfall")
			return
	if once and _fired:
		return
	_fired = true
	match kind:
		"checkpoint":
			_sprite.texture = load("res://assets/props/checkpoint_on.png")
			Audio.play_sfx("checkpoint", 0.8)
			Fx.burst(get_parent(), global_position, Color(0.4, 1.0, 0.6), 12, 80.0, 40.0, 0.5)
			p.health_component.heal(25)
		"pickup":
			Audio.play_sfx("pickup", 0.8)
			p.health_component.heal(int(payload.get("heal", 35)))
			Fx.popup_text(get_parent(), global_position + Vector2(0, -12), "+HP", Color(0.5, 1, 0.6), 10)
			queue_free()
	activated.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if body is PlayerController:
		_overlapping.erase(body as PlayerController)


## Marks a checkpoint as already reached (when respawning past it) without re-triggering effects.
func set_reached() -> void:
	_fired = true
	if kind == "checkpoint" and _sprite != null:
		_sprite.texture = load("res://assets/props/checkpoint_on.png")
