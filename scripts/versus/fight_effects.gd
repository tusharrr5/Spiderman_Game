class_name FightEffects
extends Node
## Timed buffs and debuffs on a versus fighter (Contest-of-Champions style): stat changes, damage over
## time and power drains. The fighter reads attack_mult() / defense_mult() / crit_bonus(); VersusHUD
## draws the active list as icons under the health bar.

## name, short label for the HUD icon, colour, buff/debuff
const DEFS: Dictionary = {
	"fury": {"name": "FURY", "tag": "FRY", "color": Color(1.0, 0.35, 0.25), "buff": true},
	"armor_up": {"name": "ARMOR UP", "tag": "ARM", "color": Color(0.85, 0.75, 0.4), "buff": true},
	"precision": {"name": "PRECISION", "tag": "PRC", "color": Color(1.0, 0.85, 0.3), "buff": true},
	"power_gain": {"name": "POWER GAIN", "tag": "PWR", "color": Color(0.35, 0.75, 1.0), "buff": true},
	"regen": {"name": "REGENERATION", "tag": "RGN", "color": Color(0.35, 1.0, 0.5), "buff": true},
	"bleed": {"name": "BLEED", "tag": "BLD", "color": Color(0.9, 0.1, 0.15), "buff": false},
	"shock": {"name": "SHOCK", "tag": "SHK", "color": Color(0.45, 0.85, 1.0), "buff": false},
	"poison": {"name": "POISON", "tag": "PSN", "color": Color(0.55, 0.9, 0.2), "buff": false},
	"armor_break": {"name": "ARMOR BREAK", "tag": "BRK", "color": Color(1.0, 0.6, 0.2), "buff": false},
	"weakness": {"name": "WEAKNESS", "tag": "WK", "color": Color(0.7, 0.55, 0.9), "buff": false},
	"stun": {"name": "STUN", "tag": "STN", "color": Color(1.0, 1.0, 0.6), "buff": false},
}
const MAX_STACKS: int = 3
## Set by VersusLevel while the round flow is paused (intros, KO, results) so timers and damage hold.
static var halted: bool = false

var fighter: PlayerController
## name -> {"t": seconds left, "dur": full duration, "stacks": n}
var active: Dictionary = {}
var _tick: float = 0.0
var _dot_pending: float = 0.0
var _popup_row: int = 0
var _popup_t: float = 0.0


func _init(p_fighter: PlayerController) -> void:
	fighter = p_fighter
	name = "FightEffects"


func apply(effect: String, duration: float, source: Node = null) -> void:
	if not DEFS.has(effect) or fighter == null or fighter.is_defeated():
		return
	var e: Dictionary = active.get(effect, {"t": 0.0, "dur": duration, "stacks": 0})
	e["stacks"] = mini(MAX_STACKS, int(e["stacks"]) + 1)
	e["t"] = maxf(float(e["t"]), duration)
	e["dur"] = maxf(float(e["dur"]), duration)
	active[effect] = e
	var d: Dictionary = DEFS[effect]
	var label := String(d["name"]) + (" x%d" % int(e["stacks"]) if int(e["stacks"]) > 1 else "")
	if is_instance_valid(fighter.get_parent()):
		# several effects at once stack upwards instead of printing over each other
		_popup_row = _popup_row + 1 if _popup_t > 0.0 else 0
		_popup_t = 0.6
		Fx.popup_text(fighter.get_parent(), fighter.global_position + Vector2(0, -52 - 11 * (_popup_row % 4)), label, d["color"], 9)
	if source is PlayerController and not bool(d["buff"]):
		var src := source as PlayerController
		src.stats["debuffs"] = int(src.stats.get("debuffs", 0)) + 1


func has(effect: String) -> bool:
	return active.has(effect)


func stacks(effect: String) -> int:
	return int(active[effect]["stacks"]) if active.has(effect) else 0


func clear() -> void:
	active.clear()


## Outgoing damage multiplier.
func attack_mult() -> float:
	return (1.0 + 0.15 * stacks("fury")) * (0.7 if has("weakness") else 1.0)


## Incoming damage multiplier.
func defense_mult() -> float:
	return (1.0 - 0.15 * stacks("armor_up")) * (1.0 + 0.2 * stacks("armor_break"))


func crit_bonus() -> float:
	return 0.25 * stacks("precision")


func heals_blocked() -> bool:
	return has("poison")


func _physics_process(delta: float) -> void:
	_popup_t -= delta
	if active.is_empty() or halted or fighter == null or fighter.is_defeated():
		return
	var hc := fighter.health_component
	var max_hp := float(hc.max_health)
	# damage / healing over time (percent of max health per second)
	var dot := 0.0
	dot += 0.022 * stacks("bleed")
	dot += 0.014 * stacks("shock")
	dot += 0.01 * stacks("poison")
	_dot_pending += dot * max_hp * delta
	if has("shock"):
		fighter.set_meter(fighter.power_meter - 10.0 * delta)
	if has("power_gain"):
		fighter.add_meter(18.0 * stacks("power_gain") * delta)
	if has("regen") and not heals_blocked():
		_dot_pending -= 0.012 * stacks("regen") * max_hp * delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_apply_pending()
	for k in active.keys():
		var e: Dictionary = active[k]
		e["t"] = float(e["t"]) - delta
		if float(e["t"]) <= 0.0:
			active.erase(k)


func _apply_pending() -> void:
	var amount := int(_dot_pending)
	if amount == 0:
		return
	_dot_pending -= amount
	var hc := fighter.health_component
	if amount < 0:
		hc.heal(-amount)
		return
	if hc.current_health - amount <= 0:
		# a damage-over-time KO goes through the normal defeat path
		hc.is_invulnerable = false
		hc.take_damage(amount, Vector2.ZERO, "dot")
		return
	hc.current_health -= amount
	hc.health_changed.emit(hc.current_health, hc.max_health)
	fighter.stats["damage_taken"] = int(fighter.stats.get("damage_taken", 0)) + amount
	if is_instance_valid(fighter.get_parent()):
		Fx.popup_text(fighter.get_parent(), fighter.global_position + Vector2(randf_range(-8, 8), -30), str(amount), Color(1, 0.4, 0.4), 7)
