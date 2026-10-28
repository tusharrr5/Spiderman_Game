extends RefCounted
## Scripted demo for the README GIF: drives the real Input Map actions (no cheats) through a short fight.
## Run with Godot's movie writer:  see tools/capture/record_demo.sh

var tree: SceneTree

## [frame, action, pressed]  (frames at the movie writer's fixed 30 fps)
const TIMELINE: Array = [
	[0, "move_right", true], [16, "move_right", false],
	[18, "attack_punch", true], [20, "attack_punch", false],
	[27, "attack_punch", true], [29, "attack_punch", false],
	[36, "attack_kick", true], [38, "attack_kick", false],
	[52, "move_right", true], [60, "move_right", false],
	[62, "web_action", true], [64, "web_action", false],
	[74, "special_action", true], [76, "special_action", false],
	[92, "jump", true], [104, "jump", false],
	[96, "move_right", true], [130, "move_right", false],
	[132, "attack_punch", true], [134, "attack_punch", false],
	[140, "attack_punch", true], [142, "attack_punch", false],
	[148, "attack_punch", true], [150, "attack_punch", false],
	[160, "dodge", true], [162, "dodge", false],
]
const LENGTH: int = 185


func run(p_tree: SceneTree) -> void:
	tree = p_tree
	GameState.save_path = "user://capture_save.cfg"
	GameState.routing_enabled = false
	GameState.seen_controls_guide = true
	GameState.current_level = 1
	GameState.checkpoint_index = -1
	var level := CampaignLevel.new()
	level.level_number = 1
	tree.root.add_child(level)
	await tree.process_frame
	level.hud.set_touch_visible(false)
	level.player.global_position = Vector2(1870, 230 - 16)
	(level.player.get_node("Camera2D") as Camera2D).reset_smoothing()
	for _i in range(8):
		await tree.process_frame
	for f in range(LENGTH):
		for ev in TIMELINE:
			if int(ev[0]) == f:
				if bool(ev[2]):
					Input.action_press(String(ev[1]))
				else:
					Input.action_release(String(ev[1]))
		await tree.process_frame
