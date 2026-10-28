extends SceneTree
## Headless test launcher. Loads the suites only after the first frame so the autoload singletons
## (GameState, Audio, Fx) are registered before any game script compiles.
## Usage: godot --headless --path . -s res://tests/headless_test_runner.gd

const SUITES: Array[String] = [
	"res://tests/suites/prototype_suite.gd",
	"res://tests/suites/campaign_suite.gd",
]


func _init() -> void:
	# A failed assert() aborts the coroutine without quitting; the watchdog turns that into exit code 1.
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		printerr("[FAIL] Test suite aborted or timed out (a failed assert stops the coroutine). See SCRIPT ERROR above.")
		quit(1)
	)
	await process_frame
	var only := OS.get_environment("TEST_SUITE")
	for path in SUITES:
		if only != "" and not path.contains(only):
			continue
		if not ResourceLoader.exists(path):
			continue
		var suite: RefCounted = load(path).new()
		var ok: bool = await suite.run(self)
		if not ok:
			printerr("[FAIL] suite ", path)
			quit(1)
			return
	print("=== ALL HEADLESS SUITES PASSED ===")
	quit(0)
