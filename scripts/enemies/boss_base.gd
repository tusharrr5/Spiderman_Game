class_name BossBase
extends EnemyBase
## Shared boss plumbing: HUD signals, arena engagement, vulnerability bonus damage and phase tracking.
## Signals match PrototypeBoss so the HUD and campaign level wire every boss the same way.

signal boss_engaged(boss_name: String, current_hp: int, max_hp: int)
signal boss_health_updated(current_hp: int, max_hp: int)
signal boss_status_changed(status_text: String)
signal boss_defeated()

@export var arena_trigger_x: float = 0.0
@export var arena_left_x: float = 0.0
@export var arena_right_x: float = 0.0
@export var vulnerable_bonus: float = 0.5

var engaged: bool = false
var is_vulnerable: bool = false
var phase: int = 1


func _ready() -> void:
	stagger_resist = true
	super._ready()
	add_to_group("boss")
	hp_bar_bg.visible = false
	health_component.invulnerability_duration = 0.08


func engage() -> void:
	if engaged:
		return
	engaged = true
	boss_engaged.emit(display_name, health_component.current_health, health_component.max_health)
	Audio.play_sfx("boss_warn", 0.8)


func announce(text: String) -> void:
	boss_status_changed.emit(text)


func _check_engage(player: PlayerController) -> void:
	if not engaged and player != null and player.global_position.x >= arena_trigger_x:
		engage()


func _on_hit_custom(attack_type: String, damage: int) -> void:
	if not engaged:
		engage()
	hp_bar_bg.visible = false
	Audio.play_sfx("hit", 0.7)
	if (is_vulnerable or attack_type == "thrown_object") and not health_component.is_dead:
		var bonus := int(round(float(damage) * vulnerable_bonus))
		health_component.current_health = maxi(0, health_component.current_health - bonus)
		health_component.health_changed.emit(health_component.current_health, health_component.max_health)
		if health_component.current_health <= 0:
			health_component.is_dead = true
			health_component.defeated.emit()


func _on_health_changed(current_hp: int, max_hp_value: int) -> void:
	if engaged:
		boss_health_updated.emit(current_hp, max_hp_value)


func _on_defeated() -> void:
	super._on_defeated()
	status_label.text = ""
	boss_status_changed.emit("%s DEFEATED!" % display_name)
	boss_defeated.emit()


func hp_ratio() -> float:
	return float(health_component.current_health) / float(maxi(1, health_component.max_health))
