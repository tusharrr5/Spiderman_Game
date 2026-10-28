class_name NormalEnemy
extends EnemyBase
## Street thug: patrols, chases, telegraphs ("!") and swings a baseball bat. Reacts to hits and web-snares.


func _init() -> void:
	sheet_key = "thug"
	max_hp = 50
	patrol_distance = 90.0
	patrol_speed = 55.0
	chase_speed = 92.0
	detection_range = 155.0
	attack_range = 30.0
	telegraph_duration = 0.42
	attack_duration = 0.26
	attack_cooldown = 0.95
	attack_damage = 14


func _begin_attack(_player: PlayerController) -> void:
	attack_hitbox.position = Vector2(facing_dir * 18.0, -2.0)
	attack_hitbox.activate(attack_damage, Vector2(145.0, -110.0), facing_dir, "thug_baton", 0.25)
	Audio.play_sfx("whoosh", 0.5)
