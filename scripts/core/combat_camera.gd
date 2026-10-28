class_name CombatCamera
extends Node
## Camera director. Pulls in close on melee fights (fighting-game framing), widens for traversal and web
## swinging, frames the player against the nearest threat, and runs short cinematic push-ins for specials.

const ZOOM_TRAVERSE: float = 1.25
const ZOOM_SWING: float = 1.15
const ZOOM_FIGHT: float = 1.85
const ZOOM_BOSS: float = 1.6
const ENGAGE_X: float = 150.0
const ENGAGE_Y: float = 70.0

var player: PlayerController
var cam: Camera2D
var enabled: bool = true
var _zoom: float = ZOOM_TRAVERSE
var _frame_x: float = 0.0
var _cine_time: float = 0.0
var _cine_zoom: float = 2.6
var fight_zoom_scale: float = 1.0


func _ready() -> void:
	add_to_group("camera_director")


func setup(p: PlayerController) -> void:
	player = p
	cam = p.get_node("Camera2D") as Camera2D
	_zoom = cam.zoom.x


## Short dramatic push-in on the player (specials, finishers).
func cinematic(duration: float = 0.9, zoom: float = 2.6) -> void:
	_cine_time = duration
	_cine_zoom = zoom


func is_cinematic() -> bool:
	return _cine_time > 0.0


func _process(delta: float) -> void:
	if not enabled or player == null or not is_instance_valid(player) or cam == null:
		return
	var target := ZOOM_TRAVERSE
	var frame_target := 0.0
	var threat := _nearest_threat()
	var st := player.current_state
	if st == PlayerController.State.WEB_SWINGING or st == PlayerController.State.WALL_CLIMBING \
			or st == PlayerController.State.CEILING_CRAWLING:
		target = ZOOM_SWING
	elif threat != null:
		var is_boss := threat is BossBase or threat is PrototypeBoss
		target = (ZOOM_BOSS if is_boss else ZOOM_FIGHT) * fight_zoom_scale
		frame_target = clampf((threat.global_position.x - player.global_position.x) * 0.45, -70.0, 70.0)
	if _cine_time > 0.0:
		_cine_time -= delta
		target = _cine_zoom
		frame_target = 0.0
	var rate := 6.0 if _cine_time > 0.0 else 2.2
	_zoom = lerpf(_zoom, target, 1.0 - exp(-rate * delta))
	_frame_x = lerpf(_frame_x, frame_target, 1.0 - exp(-3.0 * delta))
	cam.zoom = Vector2(_zoom, _zoom)
	# close framing: keep feet low in frame so the fight fills the screen
	var t := clampf((_zoom - ZOOM_TRAVERSE) / (ZOOM_FIGHT - ZOOM_TRAVERSE), 0.0, 1.0)
	Fx.set_camera_base(cam, Vector2(_frame_x, lerpf(-24.0, -40.0, t)))


func _nearest_threat() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var pp := player.global_position
	var seen := {}
	for e in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("boss"):
		var n := e as Node2D
		if n == null or seen.has(n) or not n.is_inside_tree() or not n.visible:
			continue
		seen[n] = true
		if n.has_method("is_defeated") and n.call("is_defeated"):
			continue
		if n is PrototypeBoss and (n as PrototypeBoss).state == PrototypeBoss.BossState.DEFEATED:
			continue
		var d := n.global_position - pp
		var reach_x := ENGAGE_X * (1.6 if (n is BossBase or n is PrototypeBoss) else 1.0)
		if absf(d.x) < reach_x and absf(d.y) < ENGAGE_Y and absf(d.x) < best_d:
			best_d = absf(d.x)
			best = n
	return best
