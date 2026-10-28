class_name LevelRegistry
extends RefCounted
## Campaign level definitions. Every chapter is pure data consumed by CampaignLevel / LevelBuilder, so new
## chapters (up to Level 20) are added here without touching the player, combat or HUD code.
##
## Coordinates: game units (640x360 view). Surfaces are listed by their TOP edge.
## solids:   [x, y_top, width, height, style]      styles: concrete, brick_red, brick_dark, metal, girder, glass, rooftile
## one_way:  [x, y_top, width, style]               thin ledges you can jump up through (fire escapes, girders)
## enemies:  {"type": thug|gunner|drone, "x", "y" (floor top, or hover y for drones), "tag", ...overrides}
## objectives (sequential): reach | defeat_tag | defeat_boss | thief_cornered | collect | break_tag | rescue | escape | scripted

const PLAYABLE_LEVELS: int = 5
const TOTAL_PLANNED_LEVELS: int = 20

## Future chapters shown as locked "coming in a later update" entries (not playable).
const FUTURE_ARCS: Array = [
	{"levels": [6, 7, 8], "arc": "SCORPION ARC", "blurb": "A venom-tailed enforcer stalks the subway lines."},
	{"levels": [9, 10, 11], "arc": "DOCTOR OCTOPUS ARC", "blurb": "Four mechanical arms tear through the science district."},
	{"levels": [12, 13, 14], "arc": "RHINO ARC", "blurb": "An armoured juggernaut rampages down Fifth Avenue."},
	{"levels": [15, 16, 17], "arc": "KRAVEN ARC", "blurb": "The hunter turns the city park into a trap."},
	{"levels": [18, 19], "arc": "SYMBIOTE SIGNS", "blurb": "Original encounters as a dark presence spreads."},
	{"levels": [20], "arc": "VENOM FINALE", "blurb": "The final showdown with Venom."},
]


static func get_level(n: int) -> Dictionary:
	match n:
		1:
			return _level_1()
		2:
			return _level_2()
		3:
			return _level_3()
		4:
			return _level_4()
		5:
			return _level_5()
	return {}


static func future_entry(n: int) -> Dictionary:
	for arc in FUTURE_ARCS:
		if n in arc["levels"]:
			return arc
	return {}


# ------------------------------------------------------------------ CHAPTER 1
static func _level_1() -> Dictionary:
	return {
		"number": 1, "chapter": "CHAPTER 1", "title": "STREET-LEVEL TROUBLE",
		"theme": "street_dusk", "music": "ch1_streets", "difficulty": 0.75,
		"bounds": Rect2(0, -220, 3360, 780), "spawn": Vector2(60, 300),
		"intro_story": "ch1_intro", "outro_story": "ch1_outro",
		"solids": [
			[-40, -300, 40, 1060, "brick_dark"],
			[0, 300, 560, 460, "concrete"],
			[650, 300, 420, 460, "brick_red"],
			[1070, 170, 430, 590, "brick_dark"],
			[1500, 390, 220, 370, "concrete"],
			[1720, 230, 580, 530, "concrete"],
			[1960, 110, 200, 22, "metal"],
			[2400, 300, 900, 460, "brick_red"],
			[3300, -300, 60, 1060, "brick_dark"],
		],
		"one_way": [[1000, 250, 70, "metal"], [1000, 205, 70, "metal"], [1650, 340, 60, "metal"], [1650, 285, 60, "metal"]],
		"anchors": [[1610, 70], [2350, 120], [2700, 150], [3000, 150]],
		"crates": [[440, 300], [1800, 230], [2150, 230], [2520, 300], [3120, 300]],
		"respawn_crates_after_x": 2400,
		"pickups": [[1900, 230], [2460, 300]],
		"props": [["ac_unit", 120, 300], ["antenna", 230, 300], ["water_tower", 520, 300], ["chimney", 760, 300],
			["streetlight", 980, 300], ["water_tower", 1380, 170], ["ac_unit", 1200, 170], ["arrow_sign", 1050, 300],
			["barrel", 1560, 390], ["ac_unit", 2250, 230], ["chimney", 2050, 230], ["water_tower", 3230, 300], ["antenna", 2450, 300]],
		"enemies": [
			{"type": "thug", "x": 380, "y": 300, "patrol_distance": 60.0},
			{"type": "thug", "x": 1300, "y": 170},
			{"type": "thug", "x": 1430, "y": 170, "patrol_distance": 40.0},
			{"type": "thug", "x": 1960, "y": 230, "tag": "gang"},
			{"type": "thug", "x": 2120, "y": 230, "tag": "gang"},
			{"type": "thug", "x": 2240, "y": 230, "tag": "gang", "patrol_distance": 30.0},
			{"type": "thug", "x": 2800, "y": 300, "tag": "arena", "detection_range": 260.0},
		],
		"boss": {"type": "brick", "x": 3050, "y": 300, "trigger_x": 2580, "left": 2440, "right": 3260, "name": "BRICK - GANG ENFORCER"},
		"checkpoints": [[1200, 170], [2450, 300]],
		"triggers": [
			{"x": 30, "dialogue": [["captain", "Night patrol, this is Captain Reyes. A gang is shaking down shop owners on 41st."],
				["hero", "On it, Captain. Nothing says 'good evening' like a surprise visit."],
				["hint", "{move} to run, {jump} to jump. Hold {up} + {jump} for a SUPER JUMP."]]},
			{"x": 300, "dialogue": [["hint", "{punch} punches (tap it for a combo), {kick} kicks, {dodge} dodges through attacks."]]},
			{"x": 880, "dialogue": [["hint", "Walls are no problem: run into the wall or hold {up} to climb. Fire escapes help too."]]},
			{"x": 1430, "dialogue": [["hero", "That gap's too wide to jump..."], ["hint", "Jump off the edge, then press {web} near a gargoyle anchor to WEB SWING. Press {jump} to let go."]]},
			{"x": 1760, "dialogue": [["hero", "There's the rest of the crew."], ["hint", "L yanks the nearest crate with a web and hurls it. No crate nearby? L does a WEB SLAM."]]},
			{"x": 2440, "dialogue": [["brick", "You're the bug who keeps ruining my collections?"], ["hero", "Collections? Is that what we're calling it now?"],
				["brick", "Get him!"]]},
		],
		"objectives": [
			{"type": "reach", "x": 1720, "text": "Follow the gang across the rooftops"},
			{"type": "defeat_tag", "tag": "gang", "text": "Stop the gang members"},
			{"type": "reach", "x": 2440, "text": "Find the gang's ringleader"},
			{"type": "defeat_boss", "text": "Defeat BRICK (hit him while he's dazed)", "music": "boss_theme"},
		],
	}


# ------------------------------------------------------------------ CHAPTER 2
static func _level_2() -> Dictionary:
	return {
		"number": 2, "chapter": "CHAPTER 2", "title": "THE ROOFTOP THIEF CHASE",
		"theme": "rooftop_sunset", "music": "ch2_chase", "difficulty": 0.9,
		"bounds": Rect2(0, -220, 4560, 780), "spawn": Vector2(60, 300),
		"intro_story": "ch2_intro", "outro_story": "ch2_outro",
		"solids": [
			[-40, -300, 40, 1060, "brick_dark"],
			[0, 300, 700, 460, "rooftile"],
			[830, 280, 570, 480, "brick_red"],
			[1520, 250, 480, 510, "concrete"],
			[2000, 320, 900, 24, "girder"],
			[2900, 290, 600, 470, "rooftile"],
			[3630, 300, 870, 460, "concrete"],
			[4500, -300, 60, 1060, "brick_dark"],
		],
		"one_way": [[2150, 230, 200, "girder"], [2500, 230, 250, "girder"], [2380, 170, 90, "girder"]],
		"moving": [{"rect": [2780, 300, 64, 12], "travel": [0, -110], "period": 3.2}],
		"anchors": [[780, 150], [1460, 120], [2250, 110], [2620, 110], [3570, 140], [3900, 150], [4250, 150]],
		"crates": [[1100, 280], [2300, 320], [3700, 300], [4300, 300]],
		"respawn_crates_after_x": 3630,
		"pickups": [[1700, 250], [2620, 230], [3680, 300]],
		"props": [["water_tower", 600, 300], ["ac_unit", 260, 300], ["antenna", 1000, 280], ["chimney", 1250, 280],
			["ac_unit", 1650, 250], ["water_tower", 1940, 250], ["barrel", 2080, 320], ["barrel", 2860, 320],
			["antenna", 3100, 290], ["ac_unit", 3350, 290], ["water_tower", 4420, 300], ["streetlight", 3700, 300]],
		"enemies": [
			{"type": "thug", "x": 520, "y": 300},
			{"type": "gunner", "x": 1250, "y": 280},
			{"type": "thug", "x": 1820, "y": 250},
			{"type": "gunner", "x": 2250, "y": 230, "patrol_distance": 40.0},
			{"type": "gunner", "x": 2650, "y": 230, "patrol_distance": 40.0},
			{"type": "thug", "x": 2450, "y": 320},
			{"type": "thug", "x": 3200, "y": 290},
			{"type": "gunner", "x": 3420, "y": 290, "patrol_distance": 30.0},
		],
		"boss": {"type": "thief", "x": 360, "y": 300, "trigger_x": 3700, "left": 3700, "right": 4460, "name": "THE THIEF",
			"respawn_ahead": 260.0, "route": [{"x": 680.0, "jump": -380.0}, {"x": 1380.0, "jump": -400.0}, {"x": 2870.0, "jump": -300.0}, {"x": 3480.0, "jump": -400.0}]},
		"checkpoints": [[1560, 250], [2060, 320], [3660, 300]],
		"triggers": [
			{"x": 30, "dialogue": [["captain", "Break-in at Halvorsen Labs! The suspect is running across the roofs - he's fast."],
				["thief", "Catch me if you can, bug!"], ["hero", "Oh, you did NOT just say that."]]},
			{"x": 700, "dialogue": [["hint", "Gaps too wide? Swing! Gunners telegraph with a red sight line - DODGE ({dodge}) through bullets."]]},
			{"x": 2040, "dialogue": [["hero", "A construction site. Of course he went through a construction site."], ["hint", "Ride the crane lift or swing between the girders."]]},
			{"x": 3640, "dialogue": [["thief", "End of the line... for YOU."], ["hero", "That's my line! Get your own material."]]},
		],
		"objectives": [
			{"type": "thief_cornered", "text": "Chase down the thief!"},
			{"type": "defeat_boss", "text": "Defeat the thief (strike after his dash)", "music": "boss_theme"},
			{"type": "collect", "id": "tech_case", "text": "Recover the stolen device"},
		],
	}


# ------------------------------------------------------------------ CHAPTER 3
static func _level_3() -> Dictionary:
	return {
		"number": 3, "chapter": "CHAPTER 3", "title": "GREEN GOBLIN AMBUSH",
		"theme": "night_industrial", "music": "ch3_ambush", "difficulty": 1.0,
		"bounds": Rect2(0, -260, 2960, 820), "spawn": Vector2(60, 300),
		"intro_story": "ch3_intro", "outro_story": "ch3_outro",
		"solids": [
			[-40, -300, 40, 1060, "brick_dark"],
			[0, 300, 620, 460, "metal"],
			[720, 300, 560, 460, "concrete"],
			[1280, 130, 90, 630, "brick_dark"],
			[1370, 260, 430, 500, "metal"],
			[1900, 300, 1000, 460, "concrete"],
			[2900, -300, 60, 1060, "brick_dark"],
		],
		"one_way": [[1210, 240, 70, "metal"], [1210, 190, 70, "metal"], [2020, 220, 120, "girder"], [2660, 220, 120, "girder"]],
		"anchors": [[670, 150], [1840, 130], [2150, 140], [2450, 120], [2750, 140]],
		"crates": [[300, 300], [1500, 260], [2000, 300], [2400, 300], [2800, 300]],
		"respawn_crates_after_x": 1900,
		"pickups": [[1450, 260], [1960, 300]],
		"hazards": [{"type": "shock", "rect": [880, 286, 160, 14], "on": 1.3, "off": 1.5}],
		"props": [["chimney", 180, 300], ["ac_unit", 470, 300], ["antenna", 600, 300], ["chimney", 800, 300],
			["water_tower", 1180, 300], ["chimney", 1600, 260], ["ac_unit", 1720, 260], ["antenna", 2860, 300], ["barrel", 1940, 300]],
		"enemies": [
			{"type": "thug", "x": 420, "y": 300},
			{"type": "drone", "x": 560, "y": 200},
			{"type": "gunner", "x": 1150, "y": 300},
			{"type": "drone", "x": 1050, "y": 190},
			{"type": "thug", "x": 1550, "y": 260},
			{"type": "gunner", "x": 1740, "y": 260, "patrol_distance": 30.0},
		],
		"boss": {"type": "goblin", "mode": "ambush", "x": 2500, "y": 160, "trigger_x": 2000, "left": 1930, "right": 2870,
			"hover_y": 170.0, "floor_y": 300.0, "name": "GREEN GOBLIN", "hp": 420},
		"checkpoints": [[740, 300], [1920, 300]],
		"triggers": [
			{"x": 30, "dialogue": [["captain", "Explosions at the old Kessler Chemical yards. Witnesses say something was FLYING."],
				["hero", "Flying. Explosions. Stolen lab tech. I hate it when the dots connect."]]},
			{"x": 520, "dialogue": [["hint", "Those drones drop pumpkin bombs when you pass beneath. Web them or punch them mid-jump."]]},
			{"x": 820, "dialogue": [["hint", "Electrified floor! Wait for the sparks to stop, or jump across."]]},
			{"x": 1940, "dialogue": [["goblin", "Ha! The little spider came to play!"], ["hero", "Green, gliding, cackling... you must be fun at parties."],
				["goblin", "Let's see how you dance with my pumpkins!"],
				["hint", "Dodge his bombs. When he SWOOPS and crashes, attack! Thrown crates knock him out of the sky."]]},
		],
		"objectives": [
			{"type": "reach", "x": 1920, "text": "Investigate the explosions at the chemical yard"},
			{"type": "scripted", "text": "Survive the Green Goblin's ambush", "music": "boss_theme"},
		],
	}


# ------------------------------------------------------------------ CHAPTER 4
static func _level_4() -> Dictionary:
	return {
		"number": 4, "chapter": "CHAPTER 4", "title": "RESCUE MISSION",
		"theme": "goblin_facility", "music": "ch4_rescue", "difficulty": 1.05,
		"bounds": Rect2(0, -200, 3700, 760), "spawn": Vector2(60, 300),
		"intro_story": "ch4_intro", "outro_story": "ch4_outro",
		"solids": [
			[-40, -300, 40, 1060, "brick_dark"],
			[0, 300, 520, 460, "concrete"],
			[520, 320, 3100, 440, "metal"],
			[600, 40, 3020, 60, "metal"],
			[520, 100, 80, 160, "metal"],
			[2380, 150, 70, 170, "metal"],
			[1180, 180, 480, 20, "metal"],
			[3620, -300, 60, 1060, "brick_dark"],
		],
		"one_way": [[2300, 230, 80, "girder"], [2450, 220, 110, "girder"], [2980, 240, 120, "girder"], [3260, 250, 120, "girder"], [3440, 195, 170, "girder"]],
		"anchors": [[1000, 120], [2050, 120], [2900, 120], [3300, 120]],
		"crates": [[700, 320], [1950, 320], [3000, 320]],
		"pickups": [[1150, 320], [2150, 320], [2860, 320]],
		"hazards": [
			{"type": "shock", "rect": [1240, 306, 120, 14], "on": 1.2, "off": 1.0},
			{"type": "shock", "rect": [1360, 306, 120, 14], "on": 1.2, "off": 1.0, "offset": 1.1},
			{"type": "shock", "rect": [1480, 306, 120, 14], "on": 1.2, "off": 1.0},
		],
		"gates": [{"id": "gate_a", "x": 1820, "y": 320, "height": 220}, {"id": "gate_b", "x": 2640, "y": 320, "height": 220}],
		"switches": [{"id": "gate_a", "x": 1740, "y": 296}, {"id": "gate_b", "x": 2500, "y": 196}],
		"cage": {"x": 3360, "y": 320},
		"interiors": [[520, 100, 3100, 220, "metal"]],
		"exit": {"x": 3560, "y": 195},
		"rescue_wave": [{"type": "drone", "x": 3200, "y": 170}, {"type": "drone", "x": 3480, "y": 150},
			{"type": "thug", "x": 3000, "y": 320}, {"type": "gunner", "x": 3420, "y": 320, "patrol_distance": 20.0}],
		"rescue_hazards": [{"type": "shock", "rect": [3000, 306, 360, 14], "on": 1.0, "off": 1.2}],
		"props": [["antenna", 200, 300], ["ac_unit", 380, 300], ["barrel", 900, 320], ["barrel", 1700, 320], ["barrel", 2200, 320],
			["barrel", 3150, 320]],
		"enemies": [
			{"type": "thug", "x": 820, "y": 320},
			{"type": "gunner", "x": 1080, "y": 320},
			{"type": "thug", "x": 1680, "y": 320},
			{"type": "gunner", "x": 1760, "y": 320, "patrol_distance": 20.0},
			{"type": "drone", "x": 2100, "y": 200},
			{"type": "thug", "x": 2250, "y": 320},
			{"type": "gunner", "x": 2500, "y": 220, "patrol_distance": 30.0},
			{"type": "drone", "x": 3000, "y": 180},
			{"type": "thug", "x": 3100, "y": 320, "tag": "guards"},
			{"type": "thug", "x": 3250, "y": 320, "tag": "guards"},
		],
		"checkpoints": [[640, 320], [1900, 320], [2720, 320]],
		"triggers": [
			{"x": 30, "dialogue": [["hero", "Every bone I own still hurts... but he has MJ. Nothing else matters tonight."],
				["mj_worried", "(radio) ...if anyone can hear this... Oscorp-style facility, east docks... please hurry..."]]},
			{"x": 1100, "dialogue": [["hint", "Electrified corridor! Jump into the CEILING while holding {up} to crawl over it. {down} or {jump} drops you."]]},
			{"x": 1620, "dialogue": [["hint", "An energy gate. Smash the GENERATOR (hit it 3 times) to shut it down."]]},
			{"x": 2400, "dialogue": [["hint", "The second generator is up on the gantry. Climb the pillar."]]},
			{"x": 2900, "dialogue": [["mj_worried", "Up here! He locked me in!"], ["hero", "Hang on, MJ - knocking first!"]]},
		],
		"objectives": [
			{"type": "reach", "x": 640, "text": "Infiltrate the Goblin's facility"},
			{"type": "break_tag", "tag": "generators", "text": "Shut down the security generators"},
			{"type": "defeat_tag", "tag": "guards", "text": "Clear the guards from the cell block"},
			{"type": "rescue", "text": "Free MJ - break the cage lock"},
			{"type": "escape", "time": 50.0, "text": "Escape with MJ - reach the gantry exit!", "music": "boss_theme"},
		],
	}


# ------------------------------------------------------------------ CHAPTER 5
static func _level_5() -> Dictionary:
	return {
		"number": 5, "chapter": "CHAPTER 5", "title": "THE FINAL GOBLIN SHOWDOWN",
		"theme": "storm_finale", "music": "ch5_showdown", "difficulty": 1.15,
		"bounds": Rect2(0, -260, 2400, 820), "spawn": Vector2(60, 300), "rain": true, "lightning": true,
		"intro_story": "ch5_intro", "outro_story": "ch5_outro",
		"solids": [
			[-40, -300, 40, 1060, "brick_dark"],
			[0, 300, 700, 460, "rooftile"],
			[760, 300, 1560, 460, "concrete"],
			[2320, -300, 60, 1060, "brick_dark"],
		],
		"one_way": [[900, 220, 140, "girder"], [1480, 200, 120, "girder"], [2040, 220, 140, "girder"]],
		"anchors": [[730, 150], [1150, 130], [1540, 110], [1900, 130], [2200, 140]],
		"crates": [[880, 300], [1300, 300], [1700, 300], [2150, 300]],
		"respawn_crates_after_x": 760,
		"pickups": [[600, 300], [1540, 200]],
		"props": [["antenna", 150, 300], ["chimney", 330, 300], ["water_tower", 640, 300], ["ac_unit", 1000, 300],
			["antenna", 1600, 300], ["water_tower", 2260, 300], ["chimney", 1880, 300]],
		"enemies": [
			{"type": "thug", "x": 300, "y": 300},
			{"type": "drone", "x": 450, "y": 190},
			{"type": "gunner", "x": 600, "y": 300, "patrol_distance": 30.0},
		],
		"boss": {"type": "goblin", "mode": "final", "x": 1600, "y": 150, "trigger_x": 840, "left": 790, "right": 2290,
			"hover_y": 150.0, "floor_y": 300.0, "name": "GREEN GOBLIN", "hp": 520},
		"checkpoints": [[780, 300]],
		"triggers": [
			{"x": 30, "dialogue": [["mj", "Be careful. Please."], ["hero", "Always am. ...Mostly. Sometimes."],
				["captain", "Every unit is evacuating the blocks around the Bridgeview tower. He's all yours."]]},
			{"x": 790, "dialogue": [["goblin", "You came back! I was SO hoping you would."], ["hero", "This ends tonight, Goblin."],
				["goblin", "Then let's make it SPECTACULAR!"],
				["hint", "Three phases. Strike when his glider crashes, throw crates to knock him down, and DODGE the bomb rain."]]},
		],
		"objectives": [
			{"type": "reach", "x": 790, "text": "Reach the Bridgeview tower rooftop"},
			{"type": "defeat_boss", "text": "Defeat the Green Goblin", "music": "boss_theme"},
		],
	}
