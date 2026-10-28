extends SceneTree
## Loads every GDScript and scene in the project so parse/compile errors surface in one headless run.
## Usage: godot --headless --path . -s res://tests/compile_check.gd


func _init() -> void:
	# autoload singletons (GameState, Audio, Fx) are registered once the main loop starts
	await process_frame
	var failures := 0
	var checked := 0
	for path in _collect("res://", [".gd", ".tscn"]):
		if path.begins_with("res://tools") or path.begins_with("res://.godot"):
			continue
		checked += 1
		var res := load(path)
		if res == null:
			failures += 1
			printerr("[FAIL] could not load ", path)
		elif res is GDScript and not (res as GDScript).can_instantiate() and not path.ends_with("compile_check.gd"):
			# abstract/utility classes still compile; can_instantiate is false only for broken scripts here
			if (res as GDScript).get_instance_base_type() == &"":
				failures += 1
				printerr("[FAIL] script did not compile ", path)
	print("compile_check: %d files, %d failures" % [checked, failures])
	quit(1 if failures > 0 else 0)


func _collect(dir: String, exts: Array) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.begins_with("."):
			f = d.get_next()
			continue
		var p := dir.path_join(f)
		if d.current_is_dir():
			out.append_array(_collect(p, exts))
		else:
			for e in exts:
				if f.ends_with(e):
					out.append(p)
		f = d.get_next()
	return out
