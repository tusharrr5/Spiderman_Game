extends RefCounted
## Scripted demo for the README GIF: drives the real Input Map actions through a short fight\n## (combo, hold-J heavy, block + S+L special with a pre-filled meter, dodge into dash strike).
## Run with Godot's movie writer:  see tools/capture/record_demo.sh

var tree: SceneTree

## [frame, action, pressed]  (frames at the movie writer's fixed 30 fps)
const TIMELINE: Array = [
	[0, "move_right", true], [12, "move_right", false],
	[14, "attack_punch", true], [16, "attack_punch", false],
	[22, "attack_punch", true], [24, "attack_punch", false],
	[30, "attack_kick", true], [32, "attack_kick", false],
	[50, "attack_punch", true], [70, "attack_punch", false],
	[88, "climb_down", true], [92, "special_action", true], [94, "special_action", false], [96, "climb_down", false],
	[150, "dodge", true], [152, "dodge", false], [156, "attack_punch", true], [158, "attack_punch", false],
]
const LENGTH: int = 190


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
	level.player.set_meter(PlayerController.METER_MAX)   # demo shows the 3-bar special
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
