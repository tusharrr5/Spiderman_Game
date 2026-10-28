class_name PrototypeLevel
extends Node2D
## Phase 1 Playable Prototype Level Controller.
## Coordinates Player, Normal Enemies, Throwable Objects, Web Swing Anchors, Prototype Boss,
## Pitfall Hazard recovery, independent InputDiagnosticsOverlay, and clean single-action Level Reset.

@onready var player: PlayerController = $Player
@onready var boss: PrototypeBoss = $PrototypeBoss
@onready var hud: HudAndTouchUI = $HudAndTouchUI

var diagnostics_overlay: InputDiagnosticsOverlay = null
var _player_spawn: Vector2 = Vector2(72.0, 260.0)


func _ready() -> void:
	_player_spawn = player.global_position

	# Instantiate independent runtime input diagnostics overlay (F3 to toggle)
	diagnostics_overlay = InputDiagnosticsOverlay.new()
	diagnostics_overlay.name = "InputDiagnosticsOverlay"
	add_child(diagnostics_overlay)
	hud.touch_button_event.connect(diagnostics_overlay.record_onscreen_button)

	# Connect Player signals to HUD
	player.health_component.health_changed.connect(hud.update_player_health)
	player.state_changed.connect(hud.update_player_state)
	player.combo_updated.connect(hud.update_combo_banner)
	player.ability_cooldown_updated.connect(hud.update_ability_cooldowns)
	player.player_died.connect(_on_player_died)

	# Connect Boss signals to HUD
	boss.boss_engaged.connect(hud.show_boss_hud)
	boss.boss_health_updated.connect(hud.update_boss_health)
	boss.boss_status_changed.connect(hud.update_boss_status)
	boss.boss_defeated.connect(_on_boss_defeated)

	# Connect HUD retry/restart signal
	hud.restart_requested.connect(restart_level)

	# Initialize HUD state
	hud.update_player_health(player.health_component.current_health, player.health_component.max_health)
	hud.update_player_state("IDLE")
	hud.update_ability_cooldowns(true, true, player.is_dark_suit)


func _physics_process(_delta: float) -> void:
	# Bottom pitfall hazard check (if player falls off building gap)
	if player != null and player.current_state != PlayerController.State.DEFEATED:
		if player.global_position.y > 430.0:
			player.health_component.take_damage(999, Vector2.ZERO, "pitfall")


func restart_level() -> void:
	# 1. Remove all active web projectiles or temporary particle nodes
	for proj in get_tree().get_nodes_in_group("projectiles"):
		if is_instance_valid(proj):
			proj.queue_free()

	# 2. Reset all throwable objects to their original positions and states
	for item in get_tree().get_nodes_in_group("throwables"):
		if item is ThrowableObject:
			(item as ThrowableObject).reset_object()

	# 3. Reset all normal enemies cleanly
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is NormalEnemy:
			(enemy as NormalEnemy).reset_enemy()

	# 4. Reset prototype boss cleanly
	if boss != null:
		boss.reset_boss()

	# 5. Reset player to initial state and spawn position
	if player != null:
		player.reset_player(_player_spawn)

	# 6. Reset HUD overlays
	if hud != null:
		hud.hide_overlays_for_reset()
		hud.update_player_health(player.health_component.current_health, player.health_component.max_health)
		hud.update_player_state("IDLE")


func _on_player_died() -> void:
	var timer := get_tree().create_timer(0.55)
	timer.timeout.connect(func() -> void:
		if player.health_component.is_dead:
			hud.show_defeat_screen()
	)


func _on_boss_defeated() -> void:
	var timer := get_tree().create_timer(0.85)
	timer.timeout.connect(func() -> void:
		if boss.health_component.is_dead:
			hud.show_victory_screen()
	)
