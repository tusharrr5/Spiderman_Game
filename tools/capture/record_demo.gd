extends SceneTree
## Launcher for the README demo recording. Use with Godot's movie writer, e.g.:
##   godot --path . --resolution 960x540 --fixed-fps 30 --write-movie /tmp/demo/frame.png -s res://tools/capture/record_demo.gd
## then build the GIF with: python3 tools/capture/make_gif.py /tmp/demo docs/media/gameplay.gif


func _init() -> void:
	await process_frame
	var job: RefCounted = load("res://tools/capture/demo_job.gd").new()
	await job.run(self)
	quit(0)
