class_name SpiderRoster
extends RefCounted
## Versus roster: 20 Spider-Verse-inspired variants (original procedural art, unofficial fan project).
## Stats are multipliers around 1.0; passives and special styles make each fighter play differently.

const PASSIVES: Dictionary = {
	"venom": "Venom Strike: specials and hits stun longer",
	"regen": "Healing factor: slowly regenerates health",
	"crit": "Spider-Sense: 18% chance of critical hits",
	"armor": "Reinforced: halves one hit every 6 seconds",
	"lifesteal": "Feral: heals a little from every hit",
	"meter": "Focused: +30% power meter gain",
	"heavy": "Haymaker: heavy attacks deal +35% damage",
	"evasion": "Slippery: longer recovery invulnerability",
	"web": "Web Master: web shots snare 60% longer",
}

## key -> [name, sheet, hp, power, speed, defense, passive, style, colour, [sp1, sp2, sp3], tagline]
const DATA: Dictionary = {
	"miles": ["MILES MORALES", "sv_miles", 100, 1.05, 1.1, 1.0, "venom", "blast", Color(0.95, 0.15, 0.2), ["VENOM BLAST", "CAMO WHIRL", "LEAP OF FAITH"], "Brooklyn's newest Spider-Man"],
	"peter_b": ["PETER B. PARKER", "sv_peter_b", 115, 1.0, 0.92, 0.9, "heavy", "slam", Color(0.95, 0.3, 0.3), ["WEB SLAM", "TIRED WHIRLWIND", "VETERAN FURY"], "Older, tired, still unstoppable"],
	"gwen": ["SPIDER-GWEN", "sv_gwen", 92, 1.0, 1.18, 1.05, "evasion", "slam", Color(0.95, 0.45, 0.7), ["BALLET KICK", "PIROUETTE STORM", "ENCORE"], "Drummer, dancer, web-slinger"],
	"noir": ["SPIDER-MAN NOIR", "sv_noir", 105, 1.12, 0.95, 0.95, "crit", "slam", Color(0.8, 0.8, 0.85), ["SHADOW SLAM", "TRENCH-COAT SPIN", "BLACK-AND-WHITE BARRAGE"], "Fights in black and white"],
	"peni": ["PENI & SP//DR", "sv_peni", 130, 1.1, 0.85, 0.82, "armor", "blast", Color(1.0, 0.4, 0.7), ["SP//DR LASER", "MECH SPIN", "OVERDRIVE"], "A girl and her psychic mech"],
	"ham": ["SPIDER-HAM", "sv_ham", 90, 0.95, 1.15, 1.05, "lifesteal", "slam", Color(1.0, 0.6, 0.7), ["CARTOON SLAM", "TOON TORNADO", "THAT'S ALL FOLKS"], "A spider bitten by a pig"],
	"2099": ["SPIDER-MAN 2099", "sv_2099", 108, 1.12, 1.05, 0.95, "crit", "blast", Color(0.95, 0.25, 0.25), ["TALON BEAM", "FUTURE SPIN", "TALON RUSH"], "Leader from the year 2099"],
	"punk": ["SPIDER-PUNK", "sv_punk", 98, 1.08, 1.08, 1.0, "meter", "blast", Color(0.4, 0.6, 1.0), ["AMP BLAST", "MOSH PIT", "ENCORE RIOT"], "Anarchy in the web"],
	"india": ["SPIDER-MAN INDIA", "sv_india", 100, 1.05, 1.12, 1.0, "regen", "slam", Color(1.0, 0.75, 0.25), ["CHAKRA SLAM", "CHAKRA SPIN", "MUMBATTAN MAYHEM"], "Pavitr, protector of Mumbattan"],
	"jess": ["SPIDER-WOMAN", "sv_jess", 104, 1.08, 1.05, 0.95, "venom", "blast", Color(1.0, 0.85, 0.25), ["VENOM BOLT", "STORM DIVE", "MOTO STRIKE"], "Detective, rider, venom blaster"],
	"scarlet": ["SCARLET SPIDER", "sv_scarlet", 106, 1.1, 1.02, 0.95, "lifesteal", "slam", Color(1.0, 0.25, 0.3), ["STINGER SLAM", "CLONE CYCLONE", "CLONE FURY"], "The clone who chose the mask"],
	"uk": ["SPIDER-UK", "sv_uk", 102, 1.05, 1.0, 0.95, "armor", "slam", Color(0.4, 0.55, 1.0), ["CAPTAIN'S SLAM", "LION SPIN", "LION'S ROAR"], "Captain of the Spider-Corps"],
	"byte": ["SPIDER-BYTE", "sv_byte", 90, 1.0, 1.15, 1.05, "meter", "blast", Color(0.35, 0.95, 1.0), ["GLITCH SHOT", "PIXEL STORM", "SYSTEM CRASH"], "A hacker living in the network"],
	"classic": ["PETER PARKER", "hero_classic", 100, 1.05, 1.05, 1.0, "crit", "slam", Color(1.0, 0.9, 0.35), ["WEB IMPACT SLAM", "WEB WHIRLWIND", "MAXIMUM SPIDER"], "The original web-slinger"],
	"symbiote": ["SYMBIOTE SPIDER-MAN", "hero_dark", 110, 1.15, 1.08, 0.95, "lifesteal", "slam", Color(0.7, 0.7, 1.0), ["SYMBIOTE SLAM", "TENDRIL STORM", "BLACK SUIT RAGE"], "Power with a price"],
	"iron": ["IRON SPIDER", "sv_iron", 112, 1.08, 1.0, 0.85, "armor", "blast", Color(1.0, 0.8, 0.3), ["NANO BLAST", "WALDO SPIN", "INSTANT KILL MODE"], "Nanotech armour, four extra arms"],
	"bagman": ["BOMBASTIC BAG-MAN", "sv_bagman", 105, 1.0, 1.0, 0.95, "regen", "slam", Color(0.85, 0.65, 0.4), ["BAG SLAM", "PAPER CYCLONE", "BOMBASTIC BLITZ"], "Borrowed suit, paper bag, big heart"],
	"1967": ["SPIDER-MAN '67", "sv_1967", 100, 1.0, 1.05, 1.0, "web", "slam", Color(1.0, 0.3, 0.3), ["RETRO SLAM", "CARTOON SPIN", "SATURDAY MORNING SMASH"], "Is he strong? Listen, bud..."],
	"advanced": ["ADVANCED SUIT", "sv_advanced", 104, 1.08, 1.08, 0.95, "web", "slam", Color(0.95, 0.95, 1.0), ["WEB BOMB SLAM", "SPIDER-BRO SPIN", "CITY KNOCKOUT"], "Tech-weave suit, white spider"],
	"cyborg": ["CYBORG SPIDER-WOMAN", "sv_cyborg", 108, 1.1, 1.0, 0.9, "heavy", "blast", Color(0.75, 0.6, 1.0), ["CYBER CANNON", "CHROME WHIRL", "UPGRADE PROTOCOL"], "Half hero, half machine"],
}
const ORDER: Array[String] = ["miles", "gwen", "peter_b", "noir", "peni", "ham", "2099", "punk", "india", "jess",
	"scarlet", "uk", "byte", "classic", "symbiote", "iron", "bagman", "1967", "advanced", "cyborg"]


static func info(key: String) -> Dictionary:
	var d: Array = DATA[key]
	return {
		"key": key, "name": d[0], "sheet": d[1], "hp": d[2], "power": d[3], "speed": d[4], "defense": d[5],
		"passive": d[6], "style": d[7], "color": d[8], "specials": d[9], "tagline": d[10],
		"portrait": portrait_path(key),
	}


static func portrait_path(key: String) -> String:
	match key:
		"classic":
			return "res://assets/portraits/hero.png"
		"symbiote":
			return "res://assets/portraits/hero_dark.png"
	return "res://assets/portraits/sv_%s.png" % key


static func random_team(rng: RandomNumberGenerator, size: int, exclude: Array = []) -> Array:
	var pool: Array = []
	for k in ORDER:
		if not k in exclude:
			pool.append(k)
	var out: Array = []
	while out.size() < size and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


# ------------------------------------------------------------------ classes, signature abilities, synergies
## Class triangle (each class beats the next one): attacker with the advantage deals +12%, against it -10%.
const CLASS_ORDER: Array[String] = ["SCIENCE", "MYSTIC", "COSMIC", "TECH", "SKILL"]
const CLASS_COLORS: Dictionary = {"SCIENCE": Color(0.4, 0.95, 0.6), "MYSTIC": Color(0.85, 0.45, 1.0), "COSMIC": Color(0.4, 0.85, 1.0),
	"TECH": Color(0.45, 0.6, 1.0), "SKILL": Color(1.0, 0.45, 0.4)}
const CLASSES: Dictionary = {
	"miles": "SCIENCE", "gwen": "SCIENCE", "peter_b": "SCIENCE", "classic": "SCIENCE", "scarlet": "SCIENCE",
	"india": "MYSTIC", "uk": "MYSTIC", "ham": "MYSTIC", "1967": "MYSTIC",
	"symbiote": "COSMIC", "jess": "COSMIC", "punk": "COSMIC",
	"peni": "TECH", "2099": "TECH", "byte": "TECH", "iron": "TECH", "cyborg": "TECH", "advanced": "TECH",
	"noir": "SKILL", "bagman": "SKILL",
}
## key -> [signature debuff (heavy / SP2 inflicts it), signature buff (gained when casting SP1)]
const SIG: Dictionary = {
	"miles": ["shock", "precision"], "gwen": ["bleed", "precision"], "peter_b": ["weakness", "armor_up"],
	"noir": ["bleed", "fury"], "peni": ["shock", "armor_up"], "ham": ["weakness", "regen"],
	"2099": ["bleed", "fury"], "punk": ["armor_break", "power_gain"], "india": ["armor_break", "regen"],
	"jess": ["poison", "power_gain"], "scarlet": ["poison", "fury"], "uk": ["armor_break", "armor_up"],
	"byte": ["shock", "power_gain"], "classic": ["weakness", "precision"], "symbiote": ["poison", "fury"],
	"iron": ["shock", "armor_up"], "bagman": ["weakness", "regen"], "1967": ["armor_break", "regen"],
	"advanced": ["bleed", "precision"], "cyborg": ["armor_break", "fury"],
}
## [name, description, members, how many of them must be on the team]
const SYNERGIES: Array = [
	["INTO THE SPIDER-VERSE", "+1 power bar at the start", ["miles", "gwen", "peter_b"], 2],
	["THE PETER PARKERS", "+10% health", ["classic", "symbiote", "peter_b", "advanced", "1967"], 2],
	["SPIDER-GANG", "+20% power gain", ["noir", "ham", "peni", "punk", "india"], 2],
	["SPIDER-SOCIETY", "+10% attack", ["2099", "jess", "byte", "scarlet", "cyborg", "iron", "uk", "bagman"], 2],
]


static func class_of(key: String) -> String:
	return String(CLASSES.get(key, "SCIENCE"))


## +1 when `att` has the class advantage over `def`, -1 when it is at a disadvantage, else 0.
static func advantage(att: String, def: String) -> int:
	var a := CLASS_ORDER.find(class_of(att))
	var d := CLASS_ORDER.find(class_of(def))
	if a < 0 or d < 0 or a == d:
		return 0
	if (a + 1) % CLASS_ORDER.size() == d:
		return 1
	if (d + 1) % CLASS_ORDER.size() == a:
		return -1
	return 0


static func class_mult(att: String, def: String) -> float:
	match advantage(att, def):
		1:
			return 1.12
		-1:
			return 0.9
	return 1.0


static func sig_text(key: String) -> String:
	var s: Array = SIG.get(key, ["bleed", "fury"])
	return "Heavy & SP2 inflict %s  |  SP1 grants %s" % [FightEffects.DEFS[s[0]]["name"], FightEffects.DEFS[s[1]]["name"]]


## Synergies active for a team (3v3): [[name, description], ...]
static func team_synergies(team: Array) -> Array:
	var out: Array = []
	for s in SYNERGIES:
		var n := 0
		for k in team:
			if k in s[2]:
				n += 1
		if n >= int(s[3]):
			out.append([s[0], s[1]])
	var counts: Dictionary = {}
	for k in team:
		counts[class_of(k)] = int(counts.get(class_of(k), 0)) + 1
	for c in counts:
		if int(counts[c]) >= 2:
			out.append(["%s BOND" % c, "+8% defense"])
	return out
