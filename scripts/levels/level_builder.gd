class_name LevelBuilder
extends RefCounted
## Turns a LevelRegistry dictionary into live nodes under a world root. Shared by every chapter.

const THUG_SCENE: PackedScene = preload("res://scenes/enemies/normal_enemy.tscn")
const BRICK_SCENE: PackedScene = preload("res://scenes/enemies/prototype_boss.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/objects/throwable_object.tscn")

var data: Dictionary
var world: Node2D
var difficulty: float = 1.0
var checkpoints: Array[InteractiveZone] = []
var triggers: Array[InteractiveZone] = []
var breakables: Array[BreakableTarget] = []
var gates: Dictionary = {}
var boss: Node = null
var cage: BreakableTarget = null
var exit_zone: InteractiveZone = null


func _init(p_data: Dictionary, p_world: Node2D) -> void:
	data = p_data
	world = p_world
	difficulty = float(data.get("difficulty", 1.0))


func build_all() -> void:
	_build_interiors()
	_build_solids()
	_build_props()
	_build_anchors()
	_build_crates()
	_build_pickups()
	_build_hazards(data.get("hazards", []))
	_build_gates()
	_build_cage_and_exit()
	_build_checkpoints()
	_build_triggers()
	for e in data.get("enemies", []):
		spawn_enemy(e)
	_build_boss()


# ------------------------------------------------------------------ background
static func build_background(parent: Node, theme: String) -> void:
	var dir := "res://assets/backgrounds/%s/" % theme
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -20
	sky_layer.follow_viewport_enabled = false
	parent.add_child(sky_layer)
	var sky := TextureRect.new()
	sky.texture = load(dir + "sky.png")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_layer.add_child(sky)
	var layers := [["far.png", Vector2(0.12, 0.06), -10, -150.0], ["mid.png", Vector2(0.32, 0.16), -9, -120.0]]
	for l in layers:
		var px := Parallax2D.new()
		px.scroll_scale = l[1]
		px.repeat_size = Vector2(640, 0)
		px.repeat_times = 3
		px.z_index = l[2]
		parent.add_child(px)
		var spr := Sprite2D.new()
		spr.texture = load(dir + l[0])
		spr.centered = false
		spr.scale = Vector2(0.5, 0.5)
		spr.position = Vector2(0, l[3])
		px.add_child(spr)


# ------------------------------------------------------------------ geometry & props
func _build_interiors() -> void:
	for r in data.get("interiors", []):
		var vis := PlatformVisual.new()
		vis.rect = Rect2(r[0], r[1], r[2], r[3])
		vis.style = String(r[4])
		vis.modulate = Color(0.42, 0.5, 0.46)
		vis.show_cap = false
		world.add_child(vis)
		vis.z_index = -3
		# pillars and lights give the interior depth
		var x := float(r[0]) + 40.0
		while x < float(r[0]) + float(r[2]) - 20.0:
			var pillar := ColorRect.new()
			pillar.color = Color(0.05, 0.1, 0.07, 0.55)
			pillar.position = Vector2(x, r[1])
			pillar.size = Vector2(14, r[3])
			pillar.z_index = -3
			pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			world.add_child(pillar)
			var lamp := ColorRect.new()
			lamp.color = Color(0.5, 1.0, 0.55, 0.5)
			lamp.position = Vector2(x - 6, float(r[1]) + 6.0)
			lamp.size = Vector2(26, 3)
			lamp.z_index = -3
			lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			world.add_child(lamp)
			x += 160.0


func _build_solids() -> void:
	for r in data.get("solids", []):
		world.add_child(LevelObjects.solid(Rect2(r[0], r[1], r[2], r[3]), String(r[4])))
	for r in data.get("one_way", []):
		world.add_child(LevelObjects.solid(Rect2(r[0], r[1], r[2], 8), String(r[3]), true))
	for m in data.get("moving", []):
		var mp := MovingPlatform.new()
		var rr: Array = m["rect"]
		mp.size = Vector2(rr[2], rr[3])
		mp.position = Vector2(rr[0] + rr[2] * 0.5, rr[1] + rr[3] * 0.5)
		mp.travel = Vector2(m["travel"][0], m["travel"][1])
		mp.period = float(m.get("period", 3.0))
		world.add_child(mp)


func _build_props() -> void:
	for p in data.get("props", []):
		var sc: float = float(p[3]) if p.size() > 3 else 1.0
		var flip: bool = bool(p[4]) if p.size() > 4 else false
		world.add_child(LevelObjects.prop(String(p[0]), Vector2(p[1], p[2]), sc, flip, -1))


func _build_anchors() -> void:
	for a in data.get("anchors", []):
		world.add_child(LevelObjects.web_anchor(Vector2(a[0], a[1])))


func _build_crates() -> void:
	for c in data.get("crates", []):
		var crate := CRATE_SCENE.instantiate()
		crate.position = Vector2(c[0], float(c[1]) - 12.0)
		world.add_child(crate)


func _build_pickups() -> void:
	for p in data.get("pickups", []):
		var z := InteractiveZone.new()
		z.kind = "pickup"
		z.size = Vector2(20, 18)
		z.position = Vector2(p[0], float(p[1]) - 12.0)
		world.add_child(z)


func _build_hazards(list: Array) -> void:
	for h in list:
		var z := InteractiveZone.new()
		z.kind = String(h["type"])
		var r: Array = h["rect"]
		z.size = Vector2(r[2], r[3])
		z.position = Vector2(r[0] + r[2] * 0.5, r[1] + r[3] * 0.5)
		z.once = false
		z.payload = h
		world.add_child(z)


func spawn_hazards(list: Array) -> void:
	_build_hazards(list)


func _build_gates() -> void:
	for g in data.get("gates", []):
		var gate := SecurityGate.new()
		gate.gate_id = String(g["id"])
		gate.height = float(g.get("height", 96.0))
		gate.position = Vector2(g["x"], float(g["y"]) - gate.height * 0.5)
		world.add_child(gate)
		gates[gate.gate_id] = gate
	for sw in data.get("switches", []):
		var t := BreakableTarget.new()
		t.target_id = String(sw["id"])
		t.hits_required = 3
		t.texture_whole = "generator_on"
		t.texture_broken = "generator_off"
		t.label_text = "SMASH!"
		t.position = Vector2(sw["x"], sw["y"])
		t.add_to_group("generators")
		world.add_child(t)
		t.broken.connect(_on_switch_broken)
		breakables.append(t)


func _on_switch_broken(t: BreakableTarget) -> void:
	if gates.has(t.target_id):
		(gates[t.target_id] as SecurityGate).open_gate()


func _build_cage_and_exit() -> void:
	if data.has("cage"):
		var c: Dictionary = data["cage"]
		cage = BreakableTarget.new()
		cage.target_id = "cage"
		cage.hits_required = 5
		cage.texture_whole = "cage"
		cage.texture_broken = "cage"
		cage.label_text = "BREAK THE LOCK!"
		cage.position = Vector2(c["x"], float(c["y"]) - 28.0)
		world.add_child(cage)
	if data.has("exit"):
		var e: Dictionary = data["exit"]
		exit_zone = InteractiveZone.new()
		exit_zone.kind = "exit"
		exit_zone.zone_id = "exit"
		exit_zone.size = Vector2(30, 50)
		exit_zone.position = Vector2(e["x"], float(e["y"]) - 25.0)
		exit_zone.active = false
		world.add_child(exit_zone)


func _build_checkpoints() -> void:
	var i := 0
	for c in data.get("checkpoints", []):
		var z := InteractiveZone.new()
		z.kind = "checkpoint"
		z.index = i
		z.size = Vector2(28, 64)
		z.position = Vector2(c[0], float(c[1]) - 32.0)
		world.add_child(z)
		checkpoints.append(z)
		i += 1


func _build_triggers() -> void:
	var i := 0
	for t in data.get("triggers", []):
		var z := InteractiveZone.new()
		z.kind = "trigger"
		z.index = i
		z.payload = t
		var b: Rect2 = data["bounds"]
		z.size = Vector2(16, b.size.y)
		z.position = Vector2(float(t["x"]), b.position.y + b.size.y * 0.5)
		world.add_child(z)
		triggers.append(z)
		i += 1


# ------------------------------------------------------------------ actors
func spawn_enemy(e: Dictionary) -> Node:
	var node: EnemyBase
	match String(e["type"]):
		"gunner":
			node = GunnerEnemy.new()
		"drone":
			node = DroneEnemy.new()
		_:
			node = THUG_SCENE.instantiate() as EnemyBase
	node.difficulty = difficulty
	node.kill_y = (data["bounds"] as Rect2).end.y
	var params := e.duplicate()
	for k in ["type", "x", "y", "tag"]:
		params.erase(k)
	node.configure(params)
	if e.has("tag"):
		node.objective_tag = String(e["tag"])
	var y := float(e["y"])
	if not node.flying:
		y -= node.body_size.y * 0.5 + 1.0
	node.position = Vector2(float(e["x"]), y)
	world.add_child(node)
	return node


func _build_boss() -> void:
	if not data.has("boss"):
		return
	var b: Dictionary = data["boss"]
	match String(b["type"]):
		"brick":
			var brick := BRICK_SCENE.instantiate() as PrototypeBoss
			brick.boss_display_name = String(b.get("name", "BRICK"))
			brick.arena_trigger_x = float(b["trigger_x"])
			brick.arena_left_x = float(b["left"])
			brick.arena_right_x = float(b["right"])
			brick.position = Vector2(float(b["x"]), float(b["y"]) - 22.0)
			world.add_child(brick)
			brick.health_component.max_health = int(round(260 * difficulty))
			brick.health_component.reset_health()
			boss = brick
		"thief":
			var th := ThiefBoss.new()
			th.difficulty = difficulty
			th.kill_y = (data["bounds"] as Rect2).end.y
			th.display_name = String(b.get("name", "THE THIEF"))
			th.route = b.get("route", [])
			th.arena_trigger_x = float(b["trigger_x"])
			th.arena_left_x = float(b["left"])
			th.arena_right_x = float(b["right"])
			th.position = Vector2(float(b["x"]), float(b["y"]) - 16.0)
			world.add_child(th)
			boss = th
		"goblin":
			var g := GoblinBoss.new()
			g.difficulty = difficulty
			g.mode = String(b.get("mode", "final"))
			g.max_hp = int(b.get("hp", 420))
			g.display_name = String(b.get("name", "THE GOBLIN"))
			g.arena_trigger_x = float(b["trigger_x"])
			g.arena_left_x = float(b["left"])
			g.arena_right_x = float(b["right"])
			g.hover_y = float(b.get("hover_y", 150.0))
			g.floor_y = float(b.get("floor_y", 300.0))
			g.position = Vector2(float(b["x"]), float(b["y"]))
			world.add_child(g)
			boss = g
