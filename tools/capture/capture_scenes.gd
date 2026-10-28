extends SceneTree
## Renders real in-game screenshots (menus, every chapter, bosses) for visual QA and the README.
## Usage: godot --path . --resolution 1280x720 -s res://tools/capture/capture_scenes.gd -- <out_dir>
## The job script is loaded after the first frame so autoload singletons are registered.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://captures"
	await process_frame
	var job: RefCounted = load("res://tools/capture/capture_job.gd").new()
	await job.run(self, out)
	quit(0)
