class_name StoryData
extends RefCounted
## Original story script for the five-chapter campaign (unofficial fan project).
## Character display names live here so the cast can be renamed in one place.

const NAMES: Dictionary = {
	"hero": "SPIDER-MAN",
	"hero_dark": "SPIDER-MAN",
	"hero_injured": "SPIDER-MAN",
	"mj": "MJ",
	"mj_worried": "MJ",
	"goblin": "GREEN GOBLIN",
	"thief": "THE THIEF",
	"brick": "BRICK",
	"captain": "CAPT. REYES",
	"hint": "TIP",
	"": "",
}

## Portrait texture for each speaker key (hint/narration have none).
static func portrait_path(speaker: String) -> String:
	if speaker in ["", "hint"]:
		return ""
	return "res://assets/portraits/%s.png" % speaker


## Each story is a list of panels: {"image": story panel name, "speaker": key, "text": line}
const STORIES: Dictionary = {
	"ch1_intro": [
		{"image": "ch1_gang", "speaker": "", "text": "Midtown, 7:42 PM. The sun is going down and the city is waking up."},
		{"image": "ch1_gang", "speaker": "captain", "text": "A crew calling themselves the Rivets has been squeezing every shop on 41st Street. Their muscle is a bruiser named Brick."},
		{"image": "ch1_gang", "speaker": "hero", "text": "Shake down small businesses on MY patrol route? Not tonight."},
	],
	"ch1_outro": [
		{"image": "ch1_gang", "speaker": "brick", "text": "Ugh... you got lucky, bug. We were just the delivery boys anyway."},
		{"image": "ch1_gang", "speaker": "hero", "text": "Delivery boys? Delivering what? ...To whom?"},
		{"image": "ch1_gang", "speaker": "brick", "text": "Some lab job across town tonight. Big money. Big green money. That's all I know."},
		{"image": "ch1_gang", "speaker": "captain", "text": "Good work. We'll take it from here. Get some rest - this city never lets you have much."},
	],
	"ch2_intro": [
		{"image": "ch2_chase", "speaker": "", "text": "Sunset over the Upper West Side. Alarms at Halvorsen Labs."},
		{"image": "ch2_chase", "speaker": "captain", "text": "Someone just walked out of Halvorsen Labs with an experimental power core. He's on the rooftops - heading east."},
		{"image": "ch2_chase", "speaker": "hero", "text": "A rooftop chase at sunset. Honestly? This is the best part of my job."},
	],
	"ch2_outro": [
		{"image": "ch2_tech", "speaker": "hero", "text": "Got it. Now let's see what's so special about this little light show..."},
		{"image": "ch2_tech", "speaker": "thief", "text": "You don't get it. HE paid for that. And he always collects."},
		{"image": "ch2_tech", "speaker": "", "text": "The device flickers. A grinning green face appears in the hologram - laughing."},
		{"image": "ch2_tech", "speaker": "goblin", "text": "Keep it, Spider. I've already copied everything I need. Consider it a gift... for now."},
	],
	"ch3_intro": [
		{"image": "ch3_ambush", "speaker": "", "text": "Midnight. The Kessler Chemical yards are burning."},
		{"image": "ch3_ambush", "speaker": "hero", "text": "Stolen power cores, hired muscle, a face in a hologram... and now explosions. Someone wants my attention."},
		{"image": "ch3_ambush", "speaker": "goblin", "text": "And now they have it!"},
	],
	"ch3_outro": [
		{"image": "ch3_injured", "speaker": "", "text": "A wall of pumpkin bombs. Fire. Then nothing."},
		{"image": "ch3_injured", "speaker": "goblin", "text": "Is that all? I expected so much more from the famous Spider-Man. Run home, little bug. Lick your wounds."},
		{"image": "ch3_injured", "speaker": "hero_injured", "text": "...can't... breathe... have to... get out of here..."},
		{"image": "ch3_injured", "speaker": "", "text": "Bruised and burned, Spider-Man drags himself into the night. For the first time in a long time, he lost."},
	],
	"ch4_intro": [
		{"image": "ch4_recovery", "speaker": "", "text": "Two days later. A cramped apartment in Queens."},
		{"image": "ch4_recovery", "speaker": "hero", "text": "Ribs taped, suit stitched. Not my best look. But I'm standing."},
		{"image": "ch4_captured", "speaker": "goblin", "text": "(broadcast) Spider-Man! I have something of yours. Red hair, terrible taste in boyfriends. Come and get her."},
		{"image": "ch4_captured", "speaker": "mj_worried", "text": "Don't come! It's a trap - he WANTS you here!"},
		{"image": "ch4_recovery", "speaker": "hero", "text": "Every trap has a way out. And I'm not leaving without her."},
	],
	"ch4_outro": [
		{"image": "ch4_recovery", "speaker": "mj", "text": "You came. You're hurt and you still came."},
		{"image": "ch4_recovery", "speaker": "hero", "text": "Of course I did. I was in the neighborhood. ...Sort of."},
		{"image": "ch5_showdown", "speaker": "goblin", "text": "(broadcast) Touching! Truly. Bridgeview tower, midnight. Bring the whole city if you like - it'll make a better show."},
		{"image": "ch4_recovery", "speaker": "mj", "text": "Go. Finish this. And then come back to me."},
	],
	"ch5_intro": [
		{"image": "ch5_showdown", "speaker": "", "text": "Midnight. A storm rolls over the Bridgeview tower."},
		{"image": "ch5_showdown", "speaker": "hero", "text": "Last time he had me off balance. This time I know his tricks - the swoops, the bombs, the laugh."},
		{"image": "ch5_showdown", "speaker": "goblin", "text": "Round two, Spider! Winner takes the city!"},
	],
	"ch5_outro": [
		{"image": "ch5_showdown", "speaker": "goblin", "text": "Impossible... beaten... by a BUG..."},
		{"image": "finale_victory", "speaker": "captain", "text": "We've got him. The Goblin's in custody. The city owes you one, kid."},
		{"image": "finale_victory", "speaker": "mj", "text": "You did it. You actually did it."},
		{"image": "finale_victory", "speaker": "hero", "text": "WE did it. Now... how about that dinner I keep promising you?"},
		{"image": "finale_victory", "speaker": "", "text": "The storm breaks. The city sleeps a little easier tonight. But somewhere, other villains are watching..."},
	],
}
