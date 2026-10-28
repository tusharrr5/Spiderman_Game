class_name Scoring
extends RefCounted
## Turns a run's combat stats into a score, a rank letter (D..S), 0-3 stars and a token reward.
## Shared by story chapters and arena modes so every mode feeds the same progression loop.

const RANKS: Array[String] = ["D", "C", "B", "A", "S"]


static func evaluate(stats: Dictionary, time_s: float, par_time: float, base: int = 1000) -> Dictionary:
	var hits := int(stats.get("hits", 0))
	var combo := int(stats.get("max_combo", 0))
	var parries := int(stats.get("parries", 0))
	var specials := int(stats.get("specials", 0))
	var taken := int(stats.get("damage_taken", 0))
	var time_bonus := maxi(0, int((par_time - time_s) * 6.0))
	var score := base + hits * 10 + combo * 30 + parries * 150 + specials * 100 + time_bonus - taken * 4
	score = maxi(100, score)
	var pts := 0
	pts += 2 if time_s <= par_time else (1 if time_s <= par_time * 1.35 else 0)
	pts += 2 if taken <= 30 else (1 if taken <= 90 else 0)
	pts += 2 if combo >= 15 else (1 if combo >= 7 else 0)
	pts += 1 if parries >= 2 else 0
	pts += 1 if specials >= 2 else 0
	var rank_i := 4 if pts >= 7 else (3 if pts >= 5 else (2 if pts >= 3 else (1 if pts >= 1 else 0)))
	var stars := 1 + (1 if rank_i >= 2 else 0) + (1 if rank_i >= 3 else 0)
	return {
		"score": score, "rank": RANKS[rank_i], "stars": stars, "tokens": 40 + score / 35,
		"time": time_s, "hits": hits, "max_combo": combo, "parries": parries, "specials": specials, "taken": taken,
	}
