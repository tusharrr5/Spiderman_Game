class_name GunnerEnemy
extends EnemyBase
## Ranged gang member: keeps distance, shows a red aim line while telegraphing, then fires a single bullet.
## Recovers briefly after each shot, giving the player a window to close in.

@export var preferred_distance: float = 140.0
@export var bullet_speed: float = 230.0

var _aim_line: Line2D


func _init() -> void:
	sheet_key = "gunner"
	max_hp = 40
	patrol_distance = 60.0
	chase_speed = 70.0
	detection_range = 230.0
	attack_range = 200.0
	telegraph_duration = 0.6
	attack_duration = 0.18
	recover_duration = 0.7
	attack_cooldown = 1.5
	attack_damage = 11


func _on_ready_custom() -> void:
	_aim_line = Line2D.new()
	_aim_line.width = 1.0
	_aim_line.default_color = Color(1.0, 0.2, 0.2, 0.55)
	_aim_line.visible = false
	add_child(_aim_line)


func _chase(player: PlayerController) -> void:
	var dx := player.global_position.x - global_position.x
	if absf(dx) > 2.0:
		facing_dir = signf(dx)
	var dist := absf(dx)
	if dist < preferred_distance * 0.6 and is_on_floor() and _ground_behind():
		velocity.x = -facing_dir * chase_speed      # back away to keep range
	elif dist > attack_range:
		velocity.x = facing_dir * chase_speed if _ground_ahead() else 0.0
	else:
		velocity.x = 0.0
	if dist <= attack_range and absf(player.global_position.y - global_position.y) < 60.0 and _cooldown_timer <= 0.0:
		velocity.x = 0.0
		start_telegraph()


func _ground_behind() -> bool:
	facing_dir = -facing_dir
	var ok := _ground_ahead()
	facing_dir = -facing_dir
	return ok


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _aim_line == null:
		return
	_aim_line.visible = state == AIState.TELEGRAPH
	if _aim_line.visible:
		_aim_line.clear_points()
		_aim_line.add_point(Vector2(facing_dir * 10.0, -6.0))
		_aim_line.add_point(Vector2(facing_dir * 220.0, -6.0))


func _begin_attack(_player: PlayerController) -> void:
	_aim_line.visible = false
	Audio.play_sfx("gunshot", 0.6)
	EnemyProjectile.spawn(get_parent(), "bullet", global_position + Vector2(facing_dir * 14.0, -6.0),
		Vector2(facing_dir * bullet_speed * clampf(difficulty, 0.8, 1.3), 0.0), attack_damage, self)


func _attack_tick(_delta: float) -> void:
	velocity.x = -facing_dir * 20.0
