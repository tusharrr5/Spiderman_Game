class_name DroneEnemy
extends EnemyBase
## Goblin bomb-drone: hovers and patrols at altitude; when the player passes underneath it blinks red
## and drops a pumpkin bomb. Fragile - one web shot or a jumping punch knocks it out.

@export var hover_height: float = 80.0
@export var bomb_damage: int = 14

var _base_y: float = 0.0


func _init() -> void:
	sheet_key = "drone"
	flying = true
	max_hp = 24
	body_size = Vector2(22, 16)
	patrol_distance = 100.0
	patrol_speed = 45.0
	detection_range = 300.0
	telegraph_duration = 0.5
	attack_duration = 0.2
	attack_cooldown = 2.0
	recover_duration = 0.3


func _on_ready_custom() -> void:
	_base_y = global_position.y
	hp_bar_bg.position.y = -18


func _anim_for_state() -> String:
	match state:
		AIState.TELEGRAPH:
			return "telegraph"
		AIState.HURT, AIState.SNARED:
			return "hurt"
		AIState.DEFEATED:
			return "ko"
	return "fly"


func _ai_custom(delta: float, player: PlayerController) -> bool:
	if state in [AIState.HURT, AIState.SNARED]:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		_state_timer -= delta
		if _state_timer <= 0.0:
			state = AIState.PATROL
			status_label.text = ""
		return true
	var bob := sin(_anim_clock * 3.0) * 6.0
	velocity.y = clampf((_base_y + bob - global_position.y) * 4.0, -60.0, 60.0)
	match state:
		AIState.PATROL, AIState.CHASE:
			velocity.x = facing_dir * patrol_speed
			if global_position.x <= _patrol_min_x:
				facing_dir = 1.0
			elif global_position.x >= _patrol_max_x:
				facing_dir = -1.0
			if player != null and _cooldown_timer <= 0.0:
				var d := player.global_position - global_position
				if absf(d.x) < 26.0 and d.y > 0.0 and d.y < 260.0:
					velocity.x = 0.0
					start_telegraph()
		AIState.TELEGRAPH:
			velocity.x = 0.0
			_state_timer -= delta
			if _state_timer <= 0.0:
				status_label.text = ""
				EnemyProjectile.spawn(get_parent(), "dropped_bomb", global_position + Vector2(0, 12), Vector2(0, 40), bomb_damage, self)
				_cooldown_timer = attack_cooldown / difficulty
				state = AIState.PATROL
	return true


func _on_defeated() -> void:
	super._on_defeated()
	flying = false
